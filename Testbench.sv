class transaction;
  bit clk;
  bit rst;
  bit start;
  rand bit[3:0]X;
  rand bit[3:0]Y;
  bit[7:0]Z;
  bit valid;
  
  function void display(string name,bit clk=0,bit rst=0);
    $display("%t [%s] CLK %d RST %d START %d X %d Y %d Z %d VALID %d",$time,name,clk,rst,start,X,Y,Z,valid);
  endfunction
   
endclass

class generator;
  transaction trans;
  mailbox gen2drv;
  int count; 
  event done;
  
  function new(mailbox gen2drv,event done);
    this.gen2drv=gen2drv;
    this.done=done;
  endfunction
  
  task run();
    begin
      repeat(count)
        begin
          trans=new();
          trans.randomize();
          trans.display("GEN");
          gen2drv.put(trans);
          #1;
          ->done;
          #40;
        end
    end
  endtask
endclass

class driver;
  transaction trans;
  mailbox gen2drv;
  virtual booth_int inf;
  event done;
  
  function new(mailbox gen2drv,event done,virtual booth_int inf);
    this.gen2drv=gen2drv;
    this.done=done;
    this.inf=inf;
  endfunction
  
  task reset();
    inf.rst<=0;
    inf.start<=1;
    inf.X<=0;
    inf.Y<=0;
    @(posedge inf.clk)
      inf.rst<=1;
    $display("[DRV]----------DUT RESET DONE---------");
  endtask
  
  task main();
    forever
      begin
        @(done);
        @(posedge inf.clk);
        gen2drv.get(trans);
        inf.X<=trans.X;
        inf.Y<=trans.Y;
        inf.rst<=1;
        inf.start<=1;
        trans.display("DRV",inf.clk,1);
        #1;
      end
  endtask
  
  task run();
    begin
      main();      
    end
  endtask
endclass

class monitor;
  virtual booth_int inf;
  mailbox mon2scb;
  transaction trans;
  
  function new(mailbox mon2scb,virtual booth_int inf);
    this.inf=inf;
    this.mon2scb=mon2scb;
  endfunction
  
  task run();
    forever
      begin
        @(posedge inf.clk);
        #2;
        trans=new();
        trans.clk=inf.clk;
        trans.rst=inf.rst;
        trans.start=inf.start;
        trans.X=inf.X;
        trans.Y=inf.Y;
        trans.Z=inf.Z;
        trans.valid=inf.valid;
        mon2scb.put(trans);
        trans.display("MON",inf.clk,inf.rst);

        #20;
      end
  endtask
endclass

class scoreboard;
  transaction trans;
  mailbox mon2scb;
  virtual booth_int inf;
  function new(mailbox mon2scb,virtual booth_int inf);
    this.mon2scb=mon2scb;
    this.inf=inf;
  endfunction
  
  task run();
    forever
      begin
        trans=new();
        mon2scb.get(trans);
        trans.display("SCO");
        if((trans.X*trans.Y)!=trans.Z)
          $display("Not Matched");
        else
          $display("Matched");
        
        $display("---------------------------------------------------------------------------------------------------------------------------------------");
      end
  endtask
endclass

class environment;
  transaction trans;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox gen2drv;
  mailbox mon2scb;
  event done;

  function new(virtual booth_int inf);
    gen2drv=new();
    mon2scb=new();
    gen=new(gen2drv,done);
    drv=new(gen2drv,done,inf);
    mon=new(mon2scb,inf);
    sco=new(mon2scb,inf);
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join
  endtask
  
  task run();
    begin
      pre_test();
      test();
    end
  endtask
  
endclass



module tb;
  environment env;
  bit clk;
  booth_int inf();
  
  BoothMul DUT(inf.clk,inf.rst,inf.start,inf.X,inf.Y,inf.valid,inf.Z);
  initial
    begin
      inf.clk<=0;
    end
  
  always
    #10 inf.clk=~inf.clk;
  
  initial
    begin
      env=new(inf);
      env.gen.count=10;
      env.run();
    end
  initial
    begin
      #300 $finish();
    end
      
endmodule
      
  
