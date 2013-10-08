Файл с исходниками            - proc.v
Небольшая помощь по верилогу  - guide.txt

Как запускать всё это:
1) Нужно раздобыть Icarus Verilog - компилятор и симулятор verilog
  a) С сайта http://iverilog.icarus.com/ , где есть ссылка на исходники на гитхабе
  b) С сайта http://bleyer.org/icarus/ , где есть все готовое для Windows
  c) Для установки не из всего готового есть инструкция: http://iverilog.wikia.com/wiki/Installation_Guide

2) После установки iverilog-а используются 2 команды:
  a) iverilog -o outputfilename inputfilename
  ( где inputfilename - исходники на верилог, а outputfilename - куда сохраняется скопилированный результат )
  ( эта команда компилирует исходники )
  b) vvp -n filename
  ( где filename - имя скомпилированного файла )
  ( эта команда запускает симуляцию, флаг '-n' нужен, чтобы выключить интерактивный режим )
  
Удачи!