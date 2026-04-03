// RISC-V Debug Module Interface (DMI) Package v0.13.2

package dmi_pkg;
    // DMI REGISTER ADDRESSES (7-bit) pg 20
    // Status registers
    localparam [6:0] DMI_DMSTATUS   = 7'h11;
    localparam [6:0] DMI_DMCONTROL  = 7'h10;
    localparam [6:0] DMI_HARTINFO   = 7'h12;
    // Abstract command registers
    localparam [6:0] DMI_ABSTRACTCS = 7'h16;
    localparam [6:0] DMI_COMMAND    = 7'h17;
    // Data registers
    localparam [6:0] DMI_DATA0      = 7'h04;
    localparam [6:0] DMI_DATA1      = 7'h05;
    localparam [6:0] DMI_DATA2      = 7'h06;
    localparam [6:0] DMI_DATA3      = 7'h07;
    localparam [6:0] DMI_DATA4      = 7'h08;
    localparam [6:0] DMI_DATA5      = 7'h09;
    localparam [6:0] DMI_DATA6      = 7'h0a;
    localparam [6:0] DMI_DATA7      = 7'h0b;
    localparam [6:0] DMI_DATA8      = 7'h0c;
    localparam [6:0] DMI_DATA9      = 7'h0d;
    localparam [6:0] DMI_DATA10     = 7'h0e;
    localparam [6:0] DMI_DATA11     = 7'h0f;
    // Program buffer
    localparam [6:0] DMI_PROGBUF0   = 7'h20;
    localparam [6:0] DMI_PROGBUF1   = 7'h21;
    localparam [6:0] DMI_PROGBUF2   = 7'h22;
    localparam [6:0] DMI_PROGBUF3   = 7'h23;
    localparam [6:0] DMI_PROGBUF4   = 7'h24;
    localparam [6:0] DMI_PROGBUF5   = 7'h25;
    localparam [6:0] DMI_PROGBUF6   = 7'h26;
    localparam [6:0] DMI_PROGBUF7   = 7'h27;
    localparam [6:0] DMI_PROGBUF8   = 7'h28;
    localparam [6:0] DMI_PROGBUF9   = 7'h29;
    localparam [6:0] DMI_PROGBUF10  = 7'h2a;
    localparam [6:0] DMI_PROGBUF11  = 7'h2b;
    localparam [6:0] DMI_PROGBUF12  = 7'h2c;
    localparam [6:0] DMI_PROGBUF13  = 7'h2d;
    localparam [6:0] DMI_PROGBUF14  = 7'h2e;
    localparam [6:0] DMI_PROGBUF15  = 7'h2f;

    // abstract command types pg 12
    typedef enum logic [7:0] {
        CMD_ACCESS_REG   = 8'h00,   // Read/write registers
        CMD_QUICK_ACCESS = 8'h01,   // Quick halt/execute
        CMD_ACCESS_MEM   = 8'h02    // Read/write memory
    } abstract_cmd_type_t;


    // DMSTATUS REGISTER (0x11) - STATUS (READ ONLY) pg 20
    typedef struct packed {
            logic [31:23] reserved;      
            logic         impebreak;     
            logic [21:20] reserved2;     
            logic         allhavereset; 
            logic         anyhavereset;  
            logic         allresumeack; 
            logic         anyresumeack;  
            logic         allnonexist;  
            logic         anynonexist;  
            logic         allunavail;   
            logic         anyunavail;   
            logic         allrunning;    
            logic         anyrunning;  
            logic         allhalted;     
            logic         anyhalted;    
            logic         authenticated; 
            logic         authbusy;     
            logic         hasresethaltreq;
            logic         confstrptrvalid;
            logic [3:0]   version;       // [3:0] Debug spec version (2 = v0.13)
        } dmstatus_t;

    // DMCONTROL REGISTER (0x10) - CONTROL (READ/WRITE) pg 22 
    typedef struct packed {
        logic         haltreq;        
        logic         resumereq;      
        logic         hartreset;   
        logic         ackhavereset;   
        logic [27:20] reserved1;   
        logic         hasel;         
        logic [18:5]  hartsel;       
        logic [4:2]   reserved2;     
        logic         setresethaltreq;   
        logic         clrresethaltreq;   
        logic         ndmreset;      
        logic         dmactive;      
    } dmcontrol_t;

    // ABSTRACTCS REGISTER (0x16) - ABSTRACT COMMAND STATUS (READ/WRITE) pg 27
    typedef struct packed {
        logic [31:29] progbufsize;    
        logic [28:13] reserved1;      
        logic         busy;          
        logic         reserved2;     
        logic [10:8]  cmderr;        
        logic [7:4]   reserved3;     
        logic [3:0]   datacount;     
    } abstractcs_t;

    // COMMAND REGISTER (0x17) - EXECUTE ABSTRACT COMMAND (WRITE ONLY) pg28
    typedef struct packed {
        logic [31:24] cmdtype;       // [31:24] Command type
        logic [23:0]  control;       // [23:0] Command-specific control bits
    } command_t;

    // Subtype for Access Register command (cmdtype = 0x00) pg 13
    typedef struct packed {
        logic [31:24] cmdtype;        
        logic [23:20] reserved1;      
        logic [19:17] aarsize;        
        logic         aarpostincrement; 
        logic         postexec;       
        logic         transfer;       
        logic         write;          
        logic [12:0]  reserved2;      
        logic [4:0]   regno;          // simplified implementation; in the spec 16 bits
    } cmd_access_register_t;

    // REGISTER NUMBERS (for Access Register command) pg 13
    // General Purpose Registers (0x1000-0x101f for x0-x31)
    localparam [15:0] GPR_BASE = 16'h1000;
    
    // Control and Status Registers (0x0000-0x0fff, standard RISC-V CSR numbers)
    localparam [15:0] CSR_BASE = 16'h0000;
    
    // Common CSR addresses in RISC-V privileged spec
    localparam [11:0] CSR_MHARTID = 12'hf14;  // Hart ID
    localparam [11:0] CSR_MCAUSE  = 12'h342;  // Cause
    localparam [11:0] CSR_MEPC    = 12'h341;  // Exception PC

    // DMI operation codes (bits [1:0] of DMI transaction) pg 65
    localparam [1:0] DMI_OP_NOP   = 2'b00;
    localparam [1:0] DMI_OP_READ  = 2'b01;
    localparam [1:0] DMI_OP_WRITE = 2'b10;

    // DMI response codes (bits [1:0] of DMI response) pg 65
    localparam [1:0] DMI_RESP_OK   = 2'b00;
    localparam [1:0] DMI_RESP_ERROR = 2'b10;
    localparam [1:0] DMI_RESP_BUSY = 2'b11;
    
    // Version values pg 20 
    localparam [3:0] DMSTATUS_VERSION_0_11 = 4'h1;
    localparam [3:0] DMSTATUS_VERSION_0_13 = 4'h2;

    // Abstract command error codes pg 27 
    typedef enum logic [2:0] {
        CMDERR_NONE = 3'h0,         
        CMDERR_BUSY = 3'h1,        
        CMDERR_NOT_SUPPORTED = 3'h2,  
        CMDERR_EXCEPTION = 3'h3,    
        CMDERR_HALT_RESUME = 3'h4,  
        CMDERR_BUS = 3'h5,          
        CMDERR_OTHER = 3'h7         
    } cmderr_t;
endpackage