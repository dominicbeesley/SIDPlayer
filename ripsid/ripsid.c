// base address of code
#define TUNE_BASE 0x1A00

// relocate SID STA's down by this number of pages, just below MODE 7
#define SID_SHADOW 0x0720
#define SID_BASE   0xFC20


/* 
   This version assumes all SID accesses are 3 byte opcodes. These are replaced with a JSR into a set of
   code segments that replace the STA to the SID and instead do two STAs one to our phoney copy (at SID_RELOC)
   just below Mode 7 and another to the actual SID
   
*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAXLEN 65536

#define read_word(bin, offs) ((unsigned)bin[offs + 1] + (((unsigned)bin[offs]) << 8))

#define f_mes stderr

#define BRK_TAB_SIZE 8

//escape a string to bash format
void fesc(FILE *fout, int n, unsigned char *str) {
  fputc('\'', fout);
  int i = 0;
  while (i < n && str[i]) {
    
    if (str[i] == '\'')
      fputs("\'\\\'\'", fout);
    else
      fputc(str[i], fout);
    
    i++;
  }
  fputc('\'', fout);
}

void error(const char *mess) {
  fprintf(f_mes, "%s", mess);
  exit(-1);
}

int usage(const char *mesg) {
  if (mesg)
    fprintf(stderr, "ERROR: %s\n", mesg);
  fprintf(stderr,"ripsidBRK <in.sid> <out.bbc> <in.inf>\n");
  exit(-1);
}

void fwriteword(uint16_t word, FILE *f_out) {
  fputc((char)word, f_out);
  fputc((char)(word >> 8), f_out);
}

unsigned char opcodes[] = { 0x8c, 0x8d, 0x8e, 0x99, 0x9d };

#define NEL(x) (sizeof(x)/sizeof(x[0]))

struct brk_ent {
  uint16_t addr;
  uint8_t opcode;
  uint8_t op1;
  uint8_t op2;
  struct brk_ent *next;
};

struct brk_ent *brk_ent_lst = NULL;

int main(int argc, char **argv) {

  if (argc != 4)
    usage("Incorrect number of parameters");
    
  FILE *f_in = fopen(argv[1], "rb");
  if (!f_in)
  {
    fprintf(stderr, "Cannot open %s for input\n", argv[1]);
    usage(NULL);
  }
  FILE *f_out = fopen(argv[2], "wb");
  if (!f_out)
  {
    fprintf(stderr, "Cannot open %s for output\n", argv[2]);
    usage(NULL);
  }
  FILE *f_brk = fopen(argv[3], "rb");
  if (!f_brk)
  {
    fprintf(stderr, "Cannot open %s for input\n", argv[3]);
    usage(NULL);
  }

  unsigned char *bin = (unsigned char *)malloc(MAXLEN);
  
  if (!bin) {
    error("Out of memory");
  }
  
  int sid_len = fread(bin, 1, MAXLEN, f_in);
  if (sid_len <= 0x76)
    error("Invalid SID file < 0x76 bytes long");
    
  
  if (!strncmp((const char *)bin, "RSID", 4) && !strncmp((const char *)bin, "PSID", 4))
    error("Not a sid file - invalid magic");
    
  fprintf(f_mes, "SID_TYPE=%4.4s\n", bin);
  
  unsigned version  = read_word(bin, 0x04);
  
  fprintf(f_mes, "SID_VERSION=%02x\n", version);
  
  unsigned dataoffs = read_word(bin, 0x06);
  unsigned loadaddr = read_word(bin, 0x08);
  unsigned datapad = 0; //amount to pad (between base address and load address)
  
  if (loadaddr == 0) {
    loadaddr = (unsigned)bin[dataoffs] + (((unsigned)bin[dataoffs + 1]) << 8);
    dataoffs+=2;  
  }
  
  fprintf(f_mes, "SID_OFFS=%04x\nSID_LOAD=%04x\n", dataoffs, loadaddr);
  fprintf(f_mes, "SID_TIT=");
  fesc(f_mes, 32, bin + 0x16);
  fprintf(f_mes, "\nSID_AUT=");
  fesc(f_mes, 32, bin + 0x36);
  fprintf(f_mes, "\nSID_REL=");
  fesc(f_mes, 32, bin + 0x56);
  fprintf(f_mes, "\n");
  
  if (loadaddr != TUNE_BASE)
  {
    if ((loadaddr & 0xFF00) != (TUNE_BASE & 0xFF00))
    {
      fprintf(stderr, "- BAD LOAD_ADDR %4.4x\n", loadaddr);
      exit(-2);
    }
    datapad = loadaddr & 0xFF;
  }
  
  unsigned initaddr = read_word(bin, 0x0A);
  unsigned playaddr = read_word(bin, 0x0C);
  unsigned numsongs = read_word(bin, 0x0E);
  unsigned defsong = read_word(bin, 0x10);
  
  fprintf(f_mes, "SID_INIT=%04x\nSID_PLAY=%04x\nSID_SONGS=%04x\n", initaddr, playaddr, numsongs);

  
  //make break table and jsrs into table into code
  char *line = NULL;
  size_t len = 0;
  size_t read;
  uint8_t brkcount = 0;
  while ((read = getline(&line, &len, f_brk)) != -1)
  {
    if (strncmp(line, "----DOM:BRK:", 12) == 0) {
      unsigned int addr;
      if (sscanf(line+12, "%x", &addr)) {
        uint8_t opcode = bin[dataoffs + addr];
        uint8_t op1 = bin[dataoffs + addr + 1];
        uint8_t op2 = bin[dataoffs + addr + 2];
        int found = 0;
        for (int ii = 0; ii < NEL(opcodes); ii++) {
          if (opcode == opcodes[ii])
          {
            found = 1;
            break;
          }
        }
        if (found) {
          struct brk_ent *b = malloc(sizeof(struct brk_ent));
          if (!b) usage("Out of memory");
          b->next = brk_ent_lst;
          b->addr = (uint16_t)addr;
          b->opcode = opcode;
          b->op1 = op1;
          b->op2 = op2;
          brk_ent_lst = b;
          brkcount++;
          fprintf(f_mes, "BRK_%04x=%02x\n", (unsigned)b->addr, (unsigned)b->opcode);
        } else {
          fprintf(f_mes, "echo \"Unknown opcode at %04x=%02x - skipping\"\n", addr, opcode);
        }
      }
    }
  }
 
  int i = 0;
  struct brk_ent * b = brk_ent_lst;
  uint16_t brkaddr = TUNE_BASE + sid_len - dataoffs;
  while (b) {
    
    bin[dataoffs + b->addr] = 0x20; //JSR
    bin[dataoffs + b->addr + 1] = brkaddr & 0xFF; //JSR
    bin[dataoffs + b->addr + 2] = (brkaddr >> 8); //JSR
    b = b->next;
    i++;
    brkaddr += BRK_TAB_SIZE;
  }

  //output file in .bbc format  
  fwriteword(initaddr, f_out);
  fwriteword(playaddr, f_out);
  fputc(numsongs, f_out);
  fputc(defsong, f_out);
  fwriteword(brkaddr, f_out);

 
  if (datapad > 0)
    for (unsigned x = 0; x < datapad; x++)
      fputc(0, f_out);

  fwrite(bin + dataoffs, 1, sid_len - dataoffs, f_out);
  
  //output break table
  b = brk_ent_lst;
  while (b) {
    fputc((char)b->opcode, f_out);          //bogus ST* instruction to our workspace
    uint16_t addr = (uint16_t)(b->op1 | b->op2 << 8);
    addr = addr - SID_BASE + SID_SHADOW;
    fputc(addr % 256, f_out);
    fputc(addr / 256, f_out);
    fputc((char)b->opcode, f_out);
    fputc((char)b->op1, f_out);
    fputc((char)b->op2, f_out);
    fputc((char)0x60, f_out); //rts
    fputc(0, f_out);
    b = b->next;
  }
  
  //output title info
  fprintf(f_out, " . . . \x95title:\x94 %-1.32s    \x96""author:\x94 %-1.32s     \x93release:\x94 %-1.32s    ", bin+0x16, bin+0x36, bin+0x56);
  fputc(0, f_out);
  
  return 0;
}