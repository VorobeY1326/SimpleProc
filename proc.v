// УККОМ - указатель команд ( CP )
//    clock - сигнал часов
//    start - флаг запуска процессора
//    commandAddress - входящий сигнал следующей команды
//    setCommandAddress - исходящий сигнал текущей команды
module CommandPointer(clock, start, commandAddress, setCommandAddress);

   input [0:15] setCommandAddress;
   output [0:15] commandAddress;
   reg [0:15] commandAddress;
   input start;
   input clock;

   always @(posedge clock)
   begin
     if (start)
        commandAddress <= setCommandAddress;
	 else
	 begin
		$display("FINAL RON WAS: %d", mainRegister.register);
	    $stop;
	end
   end

endmodule

// Модуль, выдающий следующий адрес команды ( Add1 )
// in - текущий адрес
// out - следующий за текущим адрес
module Add1(in, out);
	
	input [0:15] in;
	output [0:15] out;
	
	assign out = in + 24;
	
endmodule

// Модуль, раздваивающий 16-битный провод на два ( TO2 )
// Просто дублирует адрес, приходящий в in на out1 и на out2
module DoubleWire16(in, out1, out2);

	input [0:15] in;
	output [0:15] out1;
	output [0:15] out2;
	
	assign out1 = in;
	assign out2 = in;

endmodule

// Модуль, разделяющий 16-битный провод на четыре ( TO4 )
// Дублирует in в out1..4
module QuadrupleWire16(in, out1, out2, out3, out4);

	input [0:15] in;
	output [0:15] out1;
	output [0:15] out2;
	output [0:15] out3;
	output [0:15] out4;
	
	assign out1 = in;
	assign out2 = in;
	assign out3 = in;
	assign out4 = in;

endmodule

// Модуль регистрации команды ( REG )
// commandIn - 3 байтная команда, состоящая из байта операции и 2 байт адреса
// operationOut - текущая операция
// addressOut - текущий адрес
module RegCommand(commandIn, operationOut, addressOut);
	
	input [0:23] commandIn;
	output [0:7] operationOut;
	output [0:15] addressOut;
	
	assign operationOut = commandIn[0:7];
	assign addressOut = commandIn[8:23];
	
endmodule

// Модуль декомпозиции команды ( DEC )
// operationIn - вход из модуля регистрации команды
// start - флаг запуска процессора
// cmp - двухбитовый флаг сравнения числа с 0 : 00 - равно нулю, 11 - больше нуля, 10 - меньше нуля
// jump - флаг перехода на новый адрес
// choose - флаг выбора источника операнда ( память / адрес )
// write - флаг записи в память
// writeIR - флаг записи в индексный регистр
// writeReg - флаг записи в регистр Общего Назначения
// operation - флаг операции ( первые 4 бита команды, используется в АЛУ )
// clear - флаг очистки индексного регистра
module DecCommand(operationIn, start, cmp, jump, choose, write, writeReg, writeIR, operation, clear);

	input [0:7] operationIn;
	input [0:1] cmp;
	output jump;
	output start;
	output choose;
	output write;
	output writeReg;
	output writeIR;
	output [0:3] operation;
	output clear;

	assign start = ( operationIn != 8'hFF );
	assign jump =   ( operationIn == 8'hFE ||                     // безусловный переход
					( operationIn == 8'hF0 && cmp[0:0] == 0 ) ||  // переход при равно 0
					( operationIn == 8'hFE && cmp[1:1] == 1 ) );  // переход при больше 0
	assign choose = ( operationIn == 8'h15 || // считывание ИА
					  operationIn == 8'h25 ); // сложение с ИА
	assign write =  ( operationIn == 8'h00 ); // запись
	assign writeReg =   ( operationIn == 8'h11 ) ||
						( operationIn == 8'h15 ) ||
						( operationIn == 8'h21 ) ||
						( operationIn == 8'h25 ) ||
						( operationIn == 8'h31 );   // запись в РОН
	assign writeIR = 1; // запись в ИР
	assign operation = operationIn[0:3];
	assign clear = (operationIn != 8'h02 ); // запись в ИР

endmodule

// Модуль, складывающий 2 16 битных числа ( SUM16 )
module SumWires16(in1, in2, out);

	input [0:15] in2;
	input [0:15] in1;
	output [0:15] out;

	assign out = in1 + in2;

endmodule

// Мультиплексор, отвечающий за выбор адреса следующей команды ( JMX )
// nextIn - вход из Add1, несущий адрес следующей команды
// jumpIn - вход, несущий адрес возможного прыжка
// jump - флаг, прыгать или нет
// addressOut - выход к указателю команд
module JumpMultiplexor(nextIn, jumpIn, jump, addressOut);
	
	input [0:15] nextIn;
	input [0:15] jumpIn;
	input jump;
	output [0:15] addressOut;
	
	assign addressOut = jump ? jumpIn : nextIn;
	
endmodule

// Мультиплексор, отвечающий за выбор операнда АЛУ ( CMX )
// memoryIn - вход из памяти
// addressIn - вход из адреса
// choose - флаг, выбирать адрес или значение из памяти
// resultOut - это выход результата к АЛУ
module ChooseMultiplexor(memoryIn, addressIn, choose, resultOut);
	
	input [0:15] memoryIn;
	input [0:15] addressIn;
	input choose;
	output [0:15] resultOut;
	
	assign resultOut = choose ? addressIn : memoryIn;
	
endmodule

// АЛУ - арифметическое логическое устройство! ( ALU )
// operandIn - вход из памяти/адреса ( из мультиплексора CMX )
// registerIn - вход из РОН
// resultOut - результат операции над двумя входами
// markOut - результат сравнения результата с нулем ( меньше / равно / больше )
// operation - флаг, обозначающий, какую операцию провести
module Alu(operandIn, registerIn, resultOut, markOut, operation);
	
	input [0:15] operandIn;
	input [0:15] registerIn;
	input [0:3] operation;
	output [0:15] resultOut;
	output [0:1] markOut;
	
	assign resultOut = (( operation == 4'h0 ) ? registerIn :
	                   (( operation == 4'h1 ) ? operandIn :
					   (( operation == 4'h2 ) ? registerIn + operandIn :
					   (( operation == 4'h3 ) ? registerIn - operandIn :
					                             registerIn ))));
	assign markOut = ( resultOut == 0 ) ? 2'b00 :
	                 (( resultOut > 0 ) ? 2'b11 : 2'b10 );
	
endmodule

// Модуль, зануляющий провод, если выставлен флаг
// in - вход
// out - выход
// clear - флаг, занулять ли выход
module ZeroMultiplexor(in, out, clear);

	input [0:15] in;
	output [0:15] out;
	input clear;

	assign out = !clear ? in : 0;

endmodule

// Регистр общего назначения ( RON )
// resultIn - вход из АЛУ
// markIn - результат сравнения с 0, приходящий из АЛУ
// registerOut - текущее значение РОН
// markOut - результат сравнения с 0, просто копирует markIn, чтобы передать его в модуль ДЕККОМ
// clock - сигнал часов
// writeReg - флаг, записывать ли приходящее значение в регистр
module MainRegister(resultIn, markIn, registerOut, markOut, clock, writeReg);

	input [0:15] resultIn;
	input [0:1] markIn;
	output [0:15] registerOut;
	output [0:1] markOut;
	input clock;
	input writeReg;
	
	reg [0:15] register;
	
	assign markOut = markIn;
	assign registerOut = register;

	always @(posedge clock)
	begin
	if (writeReg)
		register = resultIn;
	end

endmodule

// Индексный регистер ( IR )
// resultIn - входящий результат, приходящий из АЛУ
// registerOut - текущее значение ИР
// writeIR - флаг, записывать ли значение в индексный регистр
// clock - сигнал часов
module IndexRegister(resultIn, registerOut, writeIR, clock);

	input [0:15] resultIn;
	output [0:15] registerOut;
	input writeIR;
	input clock;

	reg [0:15] register;
	
	assign registerOut = register;
	
	always @(posedge clock)
	begin
	if (writeIR)
		register = resultIn;
	end

endmodule

// Модуль памяти ( MEM )
// 256 ячеек по 16 бит
// commandIn - вход из указателя команд
// commandOut - выход к РЕГКОМ
// readIn - вход, по которому считывается информация по адресу, указанному в команде
// readOut - результат считывания по адресу readIn
// writeData - записываемая в результате выполнения операции информация
// writeAddress - куда записывать результат выполнения операции
// write - надо ли записывать в память writeData
// clock - сигнал часиков
module Memory(commandIn, commandOut, readIn, readOut, writeData, writeAddress, write, clock);

	input [0:15] commandIn;
	output [0:23] commandOut;
	input [0:15] readIn;
	output [0:15] readOut;
	input write;
	input clock;
	input [0:15] writeData;
	input [0:15] writeAddress;

	reg [0:1024] memory;

	assign commandOut = memory[commandIn +: 24];
	assign readOut = memory[readIn +: 16];

	always @(posedge clock)
	begin
	if (write)
		memory[writeAddress +: 16] = writeData;
	end

endmodule

// Главный модуль
// В нём происходит создание и соединение между собой всех устройств + вся инициализация
module main;

	// Часы
	reg clock;
	
	// Различные флаги
	wire start;
	wire jump;
	wire choose;
	wire write;
	wire writeReg;
	wire writeIR;
	wire [0:3] operation;
	wire clear;
	wire [0:1] cmp;

	// Все провода
	wire [0:15] wireCP_TO2;
	wire [0:15] wireTO2_MEM;
	wire [0:15] wireTO2_Add1;
	wire [0:15] wireAdd1_JMX;
	wire [0:15] wireJMX_CP;
	wire [0:23] wireMEM_REG;
	wire [0:7] wireREG_DEC;
	wire [0:15] wireREG_SUM;
	wire [0:15] wireIR_SUM;
	wire [0:15] wireSUM_TO4;
	wire [0:15] wireTO4_CMX;
	wire [0:15] wireTO4_MEM;
	wire [0:15] wireTO4_MWR;
	wire [0:15] wireTO4_JMX;
	wire [0:15] wireMEM_CMX;
	wire [0:15] wireCMX_ALU;
	wire [0:15] wireTO4_MWRa;
	wire [0:15] wireRON_ALU;
	wire [0:15] wireALU_TO4;
	wire [0:1] wireALU_RON;
	wire [0:15] wireTO4_RON;
	wire [0:15] wireTO4_ZMX;
	wire [0:15] wireZMX_IR;

	// Все устройства ( комментарий - номер устройства на картинке - смотри guide.txt )
	// Если захочется повыдергивать провода, то можно просто у нужного устройства не указать один из параметров
	// ( например, в создании CommandPointer строчкой ниже удалить '.commandAddress(wireCP_TO2),' )
	CommandPointer commandPointer(.clock(clock), .start(start), .commandAddress(wireCP_TO2), .setCommandAddress(wireJMX_CP)); // 1
	DoubleWire16 DoubleAddress(.in(wireCP_TO2), .out1(wireTO2_MEM), .out2(wireTO2_Add1)); // 2
	Add1 addressInc(.in(wireTO2_Add1), .out(wireAdd1_JMX)); // 3
	Memory memory(.commandIn(wireTO2_MEM), .commandOut(wireMEM_REG), .readIn(wireTO4_MEM), .readOut(wireMEM_CMX),
					.writeData(wireTO4_MWR), .writeAddress(wireTO4_MWRa), .write(write), .clock(clock)); // 4
	RegCommand regCommand(.commandIn(wireMEM_REG), .operationOut(wireREG_DEC), .addressOut(wireREG_SUM)); // 5
	DecCommand decCommand(.operationIn(wireREG_DEC), .cmp(cmp), .start(start), .jump(jump), .choose(choose),
	                        .write(write), .writeReg(writeReg), .writeIR(writeIR), .operation(operation), .clear(clear)); // 6
	SumWires16 sumAddressAndIndex(.in1(wireREG_SUM), .in2(wireIR_SUM), .out(wireSUM_TO4)); // 7
	QuadrupleWire16 quadrupleNewAddress(.in(wireSUM_TO4), .out1(wireTO4_CMX), .out2(wireTO4_MEM), .out3(wireTO4_MWRa), .out4(wireTO4_JMX)); // 8
	JumpMultiplexor jumpMultiplexor(.nextIn(wireAdd1_JMX), .jumpIn(wireTO4_JMX), .jump(jump), .addressOut(wireJMX_CP)); // 9
	ChooseMultiplexor chooseMultiplexor(.addressIn(wireTO4_CMX), .memoryIn(wireMEM_CMX), .choose(choose), .resultOut(wireCMX_ALU)); // 10
	Alu alu(.registerIn(wireRON_ALU), .operandIn(wireCMX_ALU), .resultOut(wireALU_TO4), .markOut(wireALU_RON), .operation(operation)); // 11
	QuadrupleWire16 quadrupleAluResult(.in(wireALU_TO4), .out1(wireTO4_MWR), .out2(wireTO4_RON), .out3(wireTO4_ZMX)); // 12
	ZeroMultiplexor zeroMultiplexor(.in(wireTO4_ZMX), .out(wireZMX_IR), .clear(clear)); // 13
	MainRegister mainRegister(.resultIn(wireTO4_RON), .markIn(wireALU_RON), .registerOut(wireRON_ALU), .markOut(cmp),
	                           .writeReg(writeReg), .clock(clock)); // 14
	IndexRegister indexRegister(.resultIn(wireZMX_IR), .registerOut(wireIR_SUM), .writeIR(writeIR), .clock(clock)); // 15

	// каждые 10 условных единиц времени состояние часов меняется на обратное
	always #10 clock = ~clock;

	// Дебаговый вывод каждого шага
	always @(posedge clock) begin
		$display("__________%d____________", commandPointer.commandAddress);
		$display("Command  : %h", wireREG_DEC);
		$display("");
		$display("Address  : %h", wireREG_SUM);
		$display("Register : %h", mainRegister.register);
		$display("Index reg: %h", indexRegister.register);
		$display("TO ALU   : %h", wireCMX_ALU);
		$display("ALU res  : %h", wireALU_TO4);
		$display("R MEM Adr: %h", wireTO4_MEM);
		$display("R MEM Res: %h", wireMEM_CMX);
		$display("W MEM Adr: %h", wireTO4_MWRa);
		$display("W MEM Res: %h", wireTO4_MWR);
		$display("");
		$display("jump f   : %b", jump);
		$display("choose f : %b", choose);
		$display("write f  : %b", write);
		$display("writeMR f: %b", writeReg);
		$display("writeIR f: %b", writeIR);
		$display("clear f  : %b", clear);
		$display("operat f : %h", operation);
		$display("cmp f    : %b", cmp);
		$display("");
	end

	// Инициализация всего
	initial begin
		clock = 0;
		commandPointer.commandAddress = 0;
		mainRegister.register = 0;
		indexRegister.register = 0;

		// Далее перечислен набор встроенных в процессор программ, раскомментировать их лучше по одной.

		// Программа, считающая n-ое число Фиббоначи ( n лежит в РОН )
		// -----------------------------------
		
		mainRegister.register = 14; // номер числа Фиббоначи, уменьшенное на 2(?)
		memory.memory[516+:16] = 16'h0001; // предыдущее число Ф
		memory.memory[532+:16] = 16'h0001; // текущее число Ф
		memory.memory[564+:16] = 16'h0001; // единичка, которую будем вычитать
		memory.memory[0*24+:24] = 24'h0001F4; // mov mem[500], ron
		memory.memory[1*24+:24] = 24'h110204; // mov ron, mem[516]
		memory.memory[2*24+:24] = 24'h210214; // add ron, mem[532]
		memory.memory[3*24+:24] = 24'h000224; // mov mem[548], ron
		memory.memory[4*24+:24] = 24'h110214; // mov ron, mem[532]
		memory.memory[5*24+:24] = 24'h000204; // mov mem[516], ron
		memory.memory[6*24+:24] = 24'h110224; // mov ron, mem[548]
		memory.memory[7*24+:24] = 24'h000214; // mov mem[532], ron
		memory.memory[8*24+:24] = 24'h1101F4; // mov ron, mem[500]
		memory.memory[9*24+:24] = 24'h310234; // sub ron, mem[564]
		memory.memory[10*24+:24] = 24'h0001F4; // mov mem[500], ron
		memory.memory[11*24+:24] = 24'hF00138; // jz 13
		memory.memory[12*24+:24] = 24'hFE0018; // jmp 1
		memory.memory[13*24+:24] = 24'h110214; // mov ron, mem[532]
		memory.memory[14*24+:24] = 24'hFFFFFF; // stop
		
		// -----------------------------------

		// Программа, проверяющая работу индексного регистра
		// Она задумывалась как сложение элементов массива, но не была закончена
		// В текущей реализации она складывает 16-битные числа, начиная с 500 адреса, каждый шаг сдвигаясь на 1 бит
		// Число шагов определяется числом, поставленным в РОН в начале
		// Результат складывается в РОН
		// ------------------------------------
		/*
		mainRegister.register = 5; // число элементов
		memory.memory[500+:16] = 1; // элементы массива
		memory.memory[516+:16] = 2;
		memory.memory[532+:16] = 3;
		memory.memory[548+:16] = 4;
		memory.memory[564+:16] = 5;
		memory.memory[430+:16] = 1; // инициализация единицы для вычитания
		memory.memory[470+:16] = 0; // хранение результата
		memory.memory[0*24+:24] = 24'h0001C2; // mov mem[450], ron
		memory.memory[1*24+:24] = 24'h1101C2; // mov ron, mem[450]
		
		memory.memory[2*24+:24] = 24'h020000; // mov ir, ron
		memory.memory[3*24+:24] = 24'h1101F4; // mov ron, mem[500+ir]
		memory.memory[4*24+:24] = 24'h2101D6; // add ron, mem[470]
		memory.memory[5*24+:24] = 24'h0001D6; // mov mem[470], ron
		memory.memory[6*24+:24] = 24'h1101C2; // mov ron, mem[450]
		memory.memory[7*24+:24] = 24'h3101AE; // sub ron, mem[430]
		memory.memory[8*24+:24] = 24'h0001C2; // mov mem[450], ron
		memory.memory[9*24+:24] = 24'hF00108; // jz 11
		memory.memory[10*24+:24] = 24'hFE0018; // jmp 1
		memory.memory[11*24+:24] = 24'h1101D6; // mov ron, mem[470]
		memory.memory[12*24+:24] = 24'hFFFFFF; // stop
		*/
		// ------------------------------------

	end

endmodule