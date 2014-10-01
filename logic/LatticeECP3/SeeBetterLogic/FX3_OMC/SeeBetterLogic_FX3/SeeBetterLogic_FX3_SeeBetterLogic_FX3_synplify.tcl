#-- Lattice Semiconductor Corporation Ltd.
#-- Synplify OEM project file

#device options
set_option -technology LATTICE-ECP3
set_option -part LFE3_17EA
set_option -package FTN256I
set_option -speed_grade -7

#compilation/mapping options
set_option -symbolic_fsm_compiler true
set_option -resource_sharing true

#use verilog 2001 standard option
set_option -vlog_std v2001

#map options
set_option -frequency auto
set_option -maxfan 1000
set_option -auto_constrain_io 0
set_option -disable_io_insertion false
set_option -retiming false; set_option -pipe true
set_option -force_gsr false
set_option -compiler_compatible 0
set_option -dup false

set_option -default_enum_encoding default

#simulation options


#timing analysis options



#automatic place and route (vendor) options
set_option -write_apr_constraint 1

#synplifyPro options
set_option -fix_gated_and_generated_clocks 1
set_option -update_models_cp 0
set_option -resolve_multiple_driver 0


#-- add_file options
add_file -vhdl {C:/lscc/diamond/3.2_x64/cae_library/synthesis/vhdl/ecp3.vhd}
add_file -vhdl -lib "work" {C:/lscc/diamond/3.2_x64/cae_library/synthesis/vhdl/pmi_def.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ext/FIFORecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ext/FIFODualClock.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ext/FIFO.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ext/PLL.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/ChangeDetector.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/DFFSynchronizer.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/ResetSynchronizer.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/SimpleRegister.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/BufferClear.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/ContinuousCounter.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/ShiftRegister.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/ShiftRegisterModes.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/EdgeDetector.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/PulseGenerator.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/PulseDetector.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/TopLevel.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/Settings.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/LogicClockSynchronizer.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/fx3/FX3USBClockSynchronizer.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/fx3/FX3StateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/MultiplexerStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/MultiplexerConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/MultiplexerSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/TimestampGenerator.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/DVSAERStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/DVSAERConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/DVSAERSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/APSADCStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/APSADCConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/APSADCSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/IMUStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/IMUConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/IMUSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/EventCodes.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ExtTriggerSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ExtTriggerConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ExtTriggerStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/SPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ChipBiasConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ChipBiasStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/ChipBiasSPIConfig.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/single_ram.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/TrackCell.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/VelocityCell.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/WSAER2CAVIAR2.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/AERArbriter.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/AERdata.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/BGF_OBT_top.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/CAVIAR2WSAER.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/CMCell.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/ExtRAMController.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/latch3.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/ObjectTracker.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/OBTConfigRecords.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/PRCell.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/private-source/RetinaFilter.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/MISCAERStateMachine.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/../common-source/support/FifoMerger.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/MullerCelement.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/ObjectMotionCell.vhd}
add_file -vhdl -lib "work" {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/ObjectMotionCell_tb.vhd}

#-- top module name
set_option -top_module TopLevel

#-- set result format/file last
project -result_file {E:/JAER_SVN/devices/logic/LatticeECP3/SeeBetterLogic/FX3_OMC/SeeBetterLogic_FX3/SeeBetterLogic_FX3_SeeBetterLogic_FX3.edi}

#-- error message log file
project -log_file {SeeBetterLogic_FX3_SeeBetterLogic_FX3.srf}

#-- set any command lines input by customer


#-- run Synplify with 'arrange HDL file'
project -run hdl_info_gen -fileorder
project -run
