module memory_controller_arduino (
    input clk,
    input reset,

    // Interface with x3q16
    input [15:0] request_address,
    input request_type, // 0 for read, 1 for write
    input request,
    input [15:0] memory_write, 
    output reg [15:0] data_out, 
    output reg memory_ready,
    output reg write_complete,

    // Arduino output
    output reg write_enable,
    output reg register_enable,
    output reg read_enable,
    output reg lower_bit,
    output reg upper_bit,

    // Arduino input
    input lower_byte_in,
    input upper_byte_in,

    input [7:0] data_input_pins, 
    output reg [7:0] data_output_pins,

    // New iovalue signal
    output reg iovalue,  // 0: input, 1: output

    // UART inputs
    input uart_inbound,
    input [7:0] uart_data,

    // UART outputs (for transmitting data)
    output reg uart_send,
    output reg [7:0] uart_tx_data,
    input uart_busy
);

    parameter IDLE = 5'b00000;
    parameter WRITE_SETUP = 5'b00001;
    parameter WRITE_WAIT_1 = 5'b00010;
    parameter WRITE_ADDRESS_UPPER = 5'b00011;
    parameter WRITE_WAIT_2 = 5'b00100;
    parameter LOAD_DATA_LOWER = 5'b00101;
    parameter WRITE_WAIT_3 = 5'b00110;
    parameter LOAD_DATA_UPPER = 5'b00111;
    parameter WRITE_WAIT_4 = 5'b01000;
    parameter WRITE_COMPLETE = 5'b01001;
    parameter READ_SETUP = 5'b01010;
    parameter READ_WAIT_1 = 5'b01011;
    parameter READ_ADDRESS_UPPER = 5'b01100;
    parameter READ_WAIT_2 = 5'b01101;
    parameter READ_WAIT_FOR_LOWER_BYTE = 5'b01110;
    parameter READ_LOWER_BYTE = 5'b01111;
    parameter READ_WAIT_FOR_UPPER_BYTE = 5'b10000;
    parameter READ_UPPER_BYTE = 5'b10001;
    parameter READ_COMPLETE = 5'b10010;
    parameter UART_RECEIVE = 5'b10011;
    parameter UART_TRANSMIT = 5'b10100;

    reg [4:0] state, next_state;

    reg [7:0] data_bus; 

    reg [5:0] wait_counter; 
    parameter WAIT_CYCLES = 6'd4; 

    reg uart_waiting;  
    reg [15:0] uart_memory_address; 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            memory_ready <= 1'b0;
            write_complete <= 1'b0;
            write_enable <= 1'b0;
            read_enable <= 1'b0;
            register_enable <= 1'b0;
            lower_bit <= 1'b0;
            upper_bit <= 1'b0;
            data_bus <= 8'b0;
            data_out <= 16'b0;
            wait_counter <= 6'b0;
            data_output_pins <= 8'b0; 
            iovalue <= 1'b0; // Default to input
            uart_send <= 1'b0;
            uart_tx_data <= 8'b0;
            uart_waiting <= 1'b0;
            uart_memory_address <= 16'b0;
        end else begin
            state <= next_state;

            // Manage wait counter
            if (state == WRITE_WAIT_1 || state == WRITE_WAIT_2 || state == WRITE_WAIT_3 || state == WRITE_WAIT_4 ||
                state == READ_WAIT_1 || state == READ_WAIT_2) begin
                wait_counter <= wait_counter + 1;
            end else begin
                wait_counter <= 6'b0;
            end

            case (state)
                IDLE: begin
                    memory_ready <= 1'b0;
                    write_complete <= 1'b0;
                    write_enable <= 1'b0;
                    read_enable <= 1'b0;
                    register_enable <= 1'b0;
                    lower_bit <= 1'b0;
                    upper_bit <= 1'b0;
                    data_bus <= 8'b0;
                    data_out <= 16'b0;
                    data_output_pins <= 8'b0;
                    iovalue <= 1'b0;

                    uart_send <= 1'b0;

                    if (uart_inbound) begin
                        uart_waiting <= 1'b1;
                        uart_memory_address <= 16'b111111110100000;
                        next_state <= UART_RECEIVE;
                    end else if (request && request_type == 1'b1) begin
                        next_state <= WRITE_SETUP;
                    end else if (request && request_type == 1'b0) begin
                        next_state <= READ_SETUP;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                // Write Operation
                WRITE_SETUP: begin
                    write_enable <= 1'b1;
                    register_enable <= 1'b1;
                    lower_bit <= 1'b1;
                    data_output_pins <= request_address[7:0]; 
                    iovalue <= 1'b1;
                    next_state <= WRITE_WAIT_1;
                end

                WRITE_WAIT_1: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= WRITE_ADDRESS_UPPER;
                    end else begin
                        next_state <= WRITE_WAIT_1;
                    end
                end

                WRITE_ADDRESS_UPPER: begin
                    lower_bit <= 1'b0;
                    upper_bit <= 1'b1;
                    data_output_pins <= request_address[15:8]; 
                    next_state <= WRITE_WAIT_2;
                end

                WRITE_WAIT_2: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= LOAD_DATA_LOWER;
                    end else begin
                        next_state <= WRITE_WAIT_2;
                    end
                end

                LOAD_DATA_LOWER: begin
                    register_enable <= 1'b0;
                    lower_bit <= 1'b1;
                    upper_bit <= 1'b0;
                    data_output_pins <= memory_write[7:0]; 
                    next_state <= WRITE_WAIT_3;
                end

                WRITE_WAIT_3: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= LOAD_DATA_UPPER;
                    end else begin
                        next_state <= WRITE_WAIT_3;
                    end
                end

                LOAD_DATA_UPPER: begin
                    lower_bit <= 1'b0;
                    upper_bit <= 1'b1;
                    data_output_pins <= memory_write[15:8]; 
                    next_state <= WRITE_WAIT_4;
                end

                WRITE_WAIT_4: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= WRITE_COMPLETE;
                    end else begin
                        next_state <= WRITE_WAIT_4;
                    end
                end

                WRITE_COMPLETE: begin
                    write_enable <= 1'b0;
                    upper_bit <= 1'b0;
                    write_complete <= 1'b1;
                    iovalue <= 1'b0;
                    next_state <= IDLE;
                end

                // Read Operation
                READ_SETUP: begin
                    read_enable <= 1'b1;
                    register_enable <= 1'b1;
                    lower_bit <= 1'b1;
                    data_output_pins <= request_address[7:0]; 
                    next_state <= READ_WAIT_1;
                end

                READ_WAIT_1: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= READ_ADDRESS_UPPER;
                    end else begin
                        next_state <= READ_WAIT_1;
                    end
                end

                READ_ADDRESS_UPPER: begin
                    lower_bit <= 1'b0;
                    upper_bit <= 1'b1;
                    data_output_pins <= request_address[15:8]; 
                    next_state <= READ_WAIT_2;
                end

                READ_WAIT_2: begin
                    if (wait_counter >= WAIT_CYCLES) begin
                        next_state <= READ_WAIT_FOR_LOWER_BYTE;
                    end else begin
                        next_state <= READ_WAIT_2;
                    end
                end

                READ_WAIT_FOR_LOWER_BYTE: begin
                    iovalue <= 1'b0;
                    if (lower_byte_in) begin
                        data_out[7:0] <= data_input_pins;
                        next_state <= READ_LOWER_BYTE;
                    end else begin
                        next_state <= READ_WAIT_FOR_LOWER_BYTE;
                    end
                end

                READ_LOWER_BYTE: begin
                    data_out[7:0] <= data_input_pins;
                    next_state <= READ_WAIT_FOR_UPPER_BYTE;
                end

                READ_WAIT_FOR_UPPER_BYTE: begin
                    if (upper_byte_in) begin
                        next_state <= READ_UPPER_BYTE;
                    end else begin
                        next_state <= READ_WAIT_FOR_UPPER_BYTE;
                    end
                end

                READ_UPPER_BYTE: begin
                    data_out[15:8] <= data_input_pins;
                    next_state <= READ_COMPLETE;
                end

                READ_COMPLETE: begin
                    read_enable <= 1'b0;
                    memory_ready <= 1'b1;
                    next_state <= IDLE;
                end

                // UART Receive Operation
                UART_RECEIVE: begin
                    if (uart_waiting) begin
                        uart_waiting <= 1'b0;
                        data_out[7:0] <= uart_data;
                        data_out[15:8] <= 8'b0;  
                        next_state <= READ_COMPLETE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                // UART Transmit Operation
                UART_TRANSMIT: begin
                    if (!uart_busy) begin
                        uart_send <= 1'b1;
                        uart_tx_data <= memory_write[7:0];
                        next_state <= IDLE;
                    end else begin
                        uart_send <= 1'b0;
                        next_state <= UART_TRANSMIT;
                    end
                end

                default: begin
                    next_state <= IDLE; 
                end
            endcase
        end
    end
endmodule
