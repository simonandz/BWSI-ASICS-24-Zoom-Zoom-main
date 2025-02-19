`default_nettype none

module tt_um_zoom_zoom (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,     
    input  wire       reset     
);

  wire reset;  
  wire [15:0] memory_in;
  wire memory_ready;
  wire write_complete;
  wire uart_inbound;
  wire memory_critical;
  wire [15:0] request_address;
  wire request_type;
  wire request;
  wire [15:0] data_out;
  wire [7:0] data_input_pins;
  wire [15:0] memory_write;
  wire write_enable, register_enable, read_enable, lower_bit, upper_bit, tx;  

  // input
  wire lower_byte_in = ui_in[0];
  wire upper_byte_in = ui_in[1];
  wire rx = ui_in[2];
  wire IN3 = ui_in[3];
  wire IN4 = ui_in[4];
  wire IN5 = ui_in[5];
  wire IN6 = ui_in[6];
  wire IN7 = ui_in[7];

  // output
  assign uo_out[0] = write_enable;
  assign uo_out[1] = register_enable;
  assign uo_out[2] = read_enable;
  assign uo_out[3] = lower_bit;
  assign uo_out[4] = tx;
  assign uo_out[5] = upper_bit;
  assign uo_out[6] = 0;  // unused
  assign uo_out[7] = 0;  // unused

  // input output
  assign uio_out = data_output_pins;   
  assign data_input_pins = uio_in;     
  assign uio_oe = iovalue;             

  x3q16 cpu (
      .clk(clk),
      .reset(reset),
      .memory_in(memory_in),
      .memory_ready(memory_ready),
      .write_complete(write_complete),
      .uart_inbound(uart_inbound),
      .memory_critical(memory_critical),
      .request_address(request_address),
      .request_type(request_type),
      .request(request),
      .data_out(data_out),
      .tx(tx)  
  );

  memory_controller_arduino memory_controller (
      .clk(clk),
      .reset(reset),
      .request_address(request_address),
      .request_type(request_type),
      .request(request),
      .memory_write(memory_write),
      .data_out(memory_in),
      .memory_ready(memory_ready),
      .write_complete(write_complete),
      .write_enable(write_enable),  
      .register_enable(register_enable),
      .read_enable(read_enable),
      .lower_bit(lower_bit),
      .upper_bit(upper_bit),
      .lower_byte_in(lower_byte_in),
      .upper_byte_in(upper_byte_in),
      .data_input_pins(data_input_pins),
      .data_output_pins(uio_out),
      .iovalue(uio_oe),  
      .rx(rx)
  );

  // unused pins
  wire _unused = &{ena, IN3, IN4, IN5, IN6, IN7, 1'b0};

endmodule
