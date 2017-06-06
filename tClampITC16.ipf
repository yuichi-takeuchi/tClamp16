#pragma rtGlobals = 1		// Use modern global access method.
#pragma version = 1.00	//by Yuichi Takeuchi 100921
#pragma IgorVersion = 6.0	//Igor Pro 6.0 or later
///////////////////////////////////////////////////////////////
//This procedure needs the InstruTECH ITC-16 XOP from http://www.heka.com/download/itc_download.html#xops
///////////////////////////////////////////////////////////////

Menu "tClamp16"
	SubMenu "Oscillo Protocol"
	End
	SubMenu "Stimulator Protocol"
	End
	SubMenu "Setting"
	End

"-"
	SubMenu "Initialize"
		"tClampInitialize", tClamp16Main()
		"InitializeGVs&Waves", tClamp16MainGVsWaves()
		"ITC16Reset", ITC16Reset // The A/D gains will remain at the state they were previously set, if not optinal flag /S is not set.
	End

	SubMenu "Main Control"
		"New Control", tClamp16_MainControlPanel()
		"Display Control", tClamp16_DispMainControlPanel()
		"Hide Control", tClamp16_HideMainControlPanel()
		"Close Control", DoWindow/K tClamp16MainControlPanel
		".ipf",  DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16_MainControlPanel"
	End

	SubMenu "Timer"	
		"New Panel", tClamp16_TimerPanel()
		"Display Panel", tClamp16_DisplayTimer()
		"Hide Panel", tClamp16_HideTimer()
		"Close Panel", DoWindow/K tClamp16TimerPanel
		".ipf", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16_TimerPanel"
	End

	SubMenu "tClampITC16.ipf"
		"Display Procedure", DisplayProcedure/W= 'tClampITC16.ipf'
		"Main", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16_MainControlPanel"
		"DAC", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16NewDACPanel"
 		"ADC", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16NewADCPanel"
		"Oscillo", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16NewOscilloADC"
		"Seal", DisplayProcedure/W= 'tClampITC16.ipf' "tClamp16NewSealTestADC"
		"Timer", DisplayProcedure/W='tClampITC16.ipf' "tClamp16_TimerPanel"
	End

	SubMenu "Template"
		"Oscillo Protocol Template", tClamp16OSCProtocolTemplate()
		"Stimulator Protocol Template", tClamp16StimProtocolTemplate()
		"Setting Template", tClamp16SettingTemplate()
	End
	
	"Kill All", tClamp16_KillAllWindows()
"-"
	"Help", tClamp16HelpNote()
End


///////////////////////////////////////////////////////////////////
//Menu

Function tClamp16_FolderCheck()
	If(DataFolderExists("root:Packages:tClamp16"))
		else
			If(DataFolderExists("root:Packages"))
					NewDataFolder root:Packages:tClamp16
				else
					NewDataFolder root:Packages
					NewDataFolder root:Packages:tClamp16
			endif
	endif
End

Function tClamp16Main()
	tClamp16_FolderCheck()
	tClamp16_PrepWaves()
	tClamp16_PrepGVs()	
	tClamp16_MainControlPanel()
	tClamp16_TimerPanel()
end

Function tClamp16MainGVsWaves()
	tClamp16_FolderCheck()
	tClamp16_PrepWaves()
	tClamp16_PrepGVs()	
end

Function tClamp16_PrepWaves()
	tClamp16_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16
	
	Make/O/n=1024 FIFOout, FIFOin, DigitalOut, DigitalOutSeal
		
	Variable i = 0
	For(i = 0; i <= 7; i += 1)
		Make/O/n=1024 $("SealTestADC" + Num2str(i))
		Make/O/n=1024 $("SealTestPntsADC" + Num2str(i))
		Make/O/n=1024 $("OscilloADC" + Num2str(i))
		Make/O/n=1024 $("ScaledADC" + Num2str(i))
	endFor
	
	SetDataFolder fldrSav0
end

Function tClamp16_PrepGVs()
	tClamp16_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16

	String/G StrADCRange = "10"
	String/G SelectedProtocol = "none"
	String/G StrITC16SeqDAC = "0", StrITC16SeqADC = "0", SealITC16SeqDAC = "0", SealITC16SeqADC = "0"
	String/G StrAcquisitionProcName ="tClamp16AquisitionProcX"
	String/G WaveListTemp = ""

	Variable/G NumTrial = 0
	Variable/G TimeFromTick = ticks/60, ElapsedTime = 0, TimerISITicks = ticks
	Variable/G OscilloFreq = 200000, SealTestFreq = 20000, StimulatorFreq = 200000
	Variable/G DACBit = 0, ADCBit = 0, DigitalOutBit = 0, OscilloBit = 0, RecordingBit = 0, SealTestBit = 0
	Variable/G TimerISI = 6, OscilloISI = 600, SealTestISI = 6, StimulatorISI = 600
	Variable/G OscilloCounter = 0, SealTestCounter = 0, StimulatorCounter = 0
	Variable/G OscilloCounterLimit = 0, SealTestCounterLimit = 0, StimulatorCounterLimit = 0
	Variable/G OscilloITC16ExtTrig = 0, OscilloITC16Output = 1, OscilloITC16Overflow = 1, OscilloITC16Reserved = 0, OscilloITC16Flags = 6
	Variable/G OscilloITC16Period = 5, OscilloITC16StrlenSeq = 1, OscilloSamplingNpnts = 1024, OscilloAcqTime = 0.00512
	Variable/G SealITC16Trigout = 0, SealITC16ExtTrig = 0, SealITC16Output = 1, SealITC16Overflow = 1, SealITC16Reserved = 0, SealITC16Flags = 6
	Variable/G SealITC16Period = 5, SealITC16StrlenSeq = 1, SealSamplingNpnts = 1024, SealAcqTime = 0.00512
	Variable/G StimulatorITC16Period = 5, StimulatorSamplingNpnts = 200000, StimulatorAcqTime = 1
	Variable/G StimulatorCheck = 1

	Variable i = 0
	For(i = 0; i <= 7; i +=1)
		Variable/G $("MainCheckADC" + Num2str(i)) = 0
		Variable/G $("OscilloTestCheckADC" + Num2str(i)) = 0
		Variable/G $("OscilloExpand" + Num2str(i)) = 1
		Variable/G $("SealExpand" + Num2str(i)) = 1
		Variable/G $("RecordingCheckADC" + Num2str(i)) = 0
		Variable/G $("SealTestCheckADC" + Num2str(i)) = 0
		Variable/G $("SealTestPulse" + Num2str(i)) = 0.25
		Variable/G $("OscilloCmdPulse" + Num2str(i)) = 0.25
		Variable/G $("OscilloCmdOnOff" + Num2str(i)) = 1
		Variable/G $("PipetteR" + Num2str(i)) = 1
		Variable/G $("ADCMode"+ Num2str(i)) = 0		//0: voltage-clamp, 1:current-clamp
		Variable/G $("ADCValuePoint"+ Num2str(i)) = 0
		Variable/G $("ADCValueVolt"+ Num2str(i)) = 0
		Variable/G $("ADCRange"+ Num2str(i)) = 10
		Variable/G $("InputOffset"+Num2str(i)) = 0
		Variable/G $("ADCOffset"+Num2str(i)) = 0
		Variable/G $("AmpGainADC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADC" + Num2str(i)) = 1
		Variable/G $("SealCouplingDAC_ADC" + Num2str(i)) = 0
		String/G $("LabelADC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADC" + Num2str(i)) = "A"
		String/G $("AmpGainListADC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADC" + Num2str(i)) = "none"

		Variable/G $("ADCRangeVC"+ Num2str(i)) = 10
		Variable/G $("AmpGainADCVC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADCVC" + Num2str(i)) = 1
		String/G $("LabelADCVC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADCVC" + Num2str(i)) = "A"
		String/G $("AmpGainListADCVC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADCVC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADCVC" + Num2str(i)) = "none"

		Variable/G $("ADCRangeCC"+ Num2str(i)) = 10
		Variable/G $("AmpGainADCCC" + Num2str(i)) = 1
		Variable/G $("ScalingFactorADCCC" + Num2str(i)) = 1
		String/G $("LabelADCCC" + Num2str(i)) = "ADC" + Num2str(i)
		String/G $("UnitADCCC" + Num2str(i)) = "V"
		String/G $("AmpGainListADCCC" + Num2str(i)) = "1;2;5;10;20;50;100;200;500;1000;2000"
		String/G $("CouplingDAC_ADCCC" + Num2str(i)) = "none"
		String/G $("CouplingADC_ADCCC" + Num2str(i)) = "none"
	endFor	
	
	For(i = 0; i <= 3; i +=1)
		Variable/G $("DACValueVolt" + Num2str(i)) = 0
		Variable/G $("MainCheckDAC" + Num2str(i)) = 0
		Variable/G $("CommandSensVC_DAC" + Num2str(i)) = 1
		Variable/G $("CommandSensCC_DAC" + Num2str(i)) = 1
		Variable/G $("DigitalOutCheck" + Num2str(i)) = 0
		Variable/G $("StimulatorDelay" + Num2str(i)) = 0
		Variable/G $("StimulatorInterval"+ Num2str(i)) = 0.01
		Variable/G $("StimulatorTrain"+ Num2str(i)) = 0
		Variable/G $("StimulatorDuration"+ Num2str(i)) = 0.0001
		String/G $("StimulatorTrig"+ Num2str(i)) = "main;"
	endFor
	
	SetDataFolder fldrSav0
end

Function tClamp16_KillAllWindows()
	DoAlert 2, "All tClamp16 Windows and Parameters are going to be killed. OK?"
	If(V_Flag != 1)
		Abort
	endif
	
	If(WinType("tClamp16MainControlPanel"))
		DoWindow/K tClamp16MainControlPanel
	endIf

	If(WinType("tClamp16TimerPanel"))
		DoWindow/K tClamp16TimerPanel
	endIf

	If(WinType("WinSineHertz"))
		DoWindow/K WinSineHertz
	endIf
	
	If(WinType("tClamp16FIFOout"))
		DoWindow/K tClamp16FIFOout
	endIf

	If(WinType("tClamp16FIFOin"))
		DoWindow/K tClamp16FIFOin
	endIf

	If(WinType("tClamp16DigitalOut"))
		DoWindow/K tClamp16DigitalOut
	endIf	
	
	Variable i = 0

	For(i = 0; i < 4; i += 1)
		If(WinType("tClamp16DAC" + Num2str(i)))
			DoWindow/K $("tClamp16DAC" + Num2str(i))
		endIf
	endFor
	
	For(i = 0; i < 8; i += 1)
		If(WinType("tClamp16ADC" + Num2str(i)))
			DoWindow/K $("tClamp16ADC" + Num2str(i))
		endIf
		
		If(WinType("tClamp16OscilloADC" + Num2str(i)))
			DoWindow/K $("tClamp16OscilloADC" + Num2str(i))
		endIf
		
		If(WinType("tClamp16SealTestADC" + Num2str(i)))
			DoWindow/K $("tClamp16SealTestADC" + Num2str(i))
		endIf
	endFor
end

Function tClamp16OSCProtocolTemplate()
	NewNotebook/F=0

	String strproc = ""
	strproc += "// Protocol Template" + "\r"
	strproc += "" + "\r"
	strproc += "Menu \"tClamp16\"" + "\r"
	strproc += "	SubMenu \"Protocol\"" + "\r"
	strproc += "\"any name of protocol\", tClamp16SetParamProtocolX() // any name of setting protocol" + "\r"
	strproc += "	End" + "\r"
	strproc += "End" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClamp16SetParamProtocolX() 					//any name of setting protocol" + "\r"
	strproc += "	tClamp16_FolderCheck()" + "\r"
	strproc += "	String fldrSav0= GetDataFolder(1)" + "\r"
	strproc += "	SetDataFolder root:Packages:tClamp16" + "\r"
	strproc += "" + "\r"
	strproc += "	String/G SelectedProtocol = \"protocol label X()\"	// any name of protocol" + "\r"
	strproc += "	String/G StrITC16SeqDAC = \"0\"				// must be same length" + "\r"
	strproc += "	String/G StrITC16SeqADC = \"0\"" + "\r"
	strproc += "	Variable/G RecordingCheckADC0 = 0			//Select recording channels" + "\r"
	strproc += "	Variable/G RecordingCheckADC1 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC2 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC3 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC4 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC5 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC6 = 0" + "\r"
	strproc += "	Variable/G RecordingCheckADC7 = 0" + "\r"
	strproc += "	Variable/G OscilloCmdPulse0 = 0.25			//Command output" + "\r"
	strproc += "	Variable/G OscilloCmdPulse1 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse2 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse3 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse4 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse5 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse6 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCmdPulse7 = 0.25" + "\r"
	strproc += "	Variable/G OscilloCounterLimit = 0				//Sweep number" + "\r"
	strproc += "	Variable/G OscilloSamplingNpnts = 1024 			//Number of Sampling Points at each channel" + "\r"
	strproc += "	Variable/G OscilloITC16ExtTrig = 0				//0: off, 1: on" + "\r"
	strproc += "	Variable/G OscilloITC16Output = 1				//0: off, 1: on" + "\r"
	strproc += "	Variable/G OscilloITC16Overflow = 1				//0: " + "\r"
	strproc += "	Variable/G OscilloITC16Reserved = 0			// Reserved" + "\r"
	strproc += "	Variable/G OscilloITC16Period = 5				// must be between 5 and 65535. Each sampling tick is 1 micro sec." + "\r"
	strproc += "" + "\r"
	strproc += "	///////////////////////" + "\r"
	strproc += "	//Protocol-Specific parameters and procedures are here" + "\r"
	strproc += "	///////////////////////" + "\r"
	strproc += "" + "\r"
	strproc += "	tClamp16ApplyProtocolSetting()" + "\r"
	strproc += "" + "\r"
	strproc += "	SetDataFolder fldrSav0" + "\r"
	strproc += "end" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClamp16AcquisitionProcX() //same as StrAcquisitionProcName and SelectedProtocol" + "\r"
	strproc += "	NVAR bit = root:Packages:tClamp16:RecordingBit" + "\r"
	strproc += "" + "\r"
	strproc += "	// Specific global variables here" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable i = 0" + "\r"
	strproc += "	For(i = 0; i < 8; i += 1)" + "\r"
	strproc += "		If(bit & 2^i)" + "\r"
	strproc += "			Wave OscilloADC = $(\"root:Packages:tClamp16:OscilloADC\" + Num2str(i))" + "\r"
	strproc += "			NVAR OscilloCmdPulse = $(\"root:Packages:tClamp16:OscilloCmdPulse\" + Num2str(i))		//" + "\r"
	strproc += "			NVAR OscilloCmdOnOff = $(\"root:Packages:tClamp16:OscilloCmdOnOff\" + Num2str(i))		//" + "\r"
	strproc += "" + "\r"
	strproc += "			If(OscilloCmdOnOff)" + "\r"
	strproc += "				OscilloADC[0, ] = OscilloCmdPulse	// create DAC output data in volt" + "\r"
	strproc += "				OscilloADC *= 3200										// scale into point" + "\r"
	strproc += "			else" + "\r"
	strproc += "				OscilloADC[0, ] = 0" + "\r"
	strproc += "				OscilloADC *= 3200" + "\r"
	strproc += "			endif" + "\r"
	strproc += "		endif" + "\r"
	strproc += "	endFor" + "\r"
	strproc += "" + "\r"
	strproc += "	Wave DigitalOut = $\"root:Packages:tClamp16:DigitalOut\"	//Output Wave for DigitalOut" + "\r"
	strproc += "	NVAR StimulatorCheck = root:Packages:tClamp16:StimulatorCheck" + "\r"
	strproc += "" + "\r"
	strproc += "	If(StimulatorCheck)" + "\r"
	strproc += "		tClamp16UseStimulator()" + "\r"
	strproc += "	else" + "\r"
	strproc += "//		DigitalOut = 0" + "\r"
	strproc += "	endIf" + "\r"
	strproc += "end" + "\r"
	strproc += "" + "\r"
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strproc + "\r"
end

Function tClamp16StimProtocolTemplate()
	NewNotebook/F=0

	String strproc = ""
	strproc += "// Stimulator Protocol Template" + "\r"
	strproc += "Menu \"tClamp16\"" + "\r"
	strproc += "	SubMenu \"Stimulator Protocol\"" + "\r"
	strproc += "\"any name\", tClamp16SetStim()" + "\r"
	strproc += "	End" + "\r"
	strproc += "End" + "\r"
	strproc += "" + "\r"
	strproc += "Function tClamp16SetStim()" + "\r"
	strproc += "	tClamp16_FolderCheck()" + "\r"
	strproc += "	String fldrSav0= GetDataFolder(1)" + "\r"
	strproc += "	SetDataFolder root:Packages:tClamp16" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorCheck = 1" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorCounterLimit = 0" + "\r"
	strproc += "	Variable/G StimulatorISI = 600" + "\r"
	strproc += "	Variable/G StimulatorITC16Period = 5" + "\r"
	strproc += "	Variable/G StimulatorSamplingNpnts = 200000" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay0 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval0 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain0 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration0 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay1 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval1 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain1 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration1 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay2 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval2 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain2 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration2 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	Variable/G StimulatorDelay3 = 0" + "\r"
	strproc += "	Variable/G StimulatorInterval3 = 0" + "\r"
	strproc += "	Variable/G StimulatorTrain3 = 0" + "\r"
	strproc += "	Variable/G StimulatorDuration3 = 0" + "\r"
	strproc += "" + "\r"
	strproc += "	tClamp16ApplyStimulatorSetting()" + "\r"
	strproc += "" + "\r"
	strproc += "	SetDataFolder fldrSav0" + "\r"
	strproc += "End" + "\r"
	
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strproc + "\r"
end

Function tClamp16SettingTemplate()
	NewNotebook/F=0
	String strset =""
	strset += "Menu \"tClamp16\""+"\r"
	strset += "	SubMenu \"Setting\""+"\r"
	strset += "\"Setting A\", tClamp16SettingTemplateA()"+"\r"
	strset += "	End"+"\r"
	strset += "End"+"\r"
	strset += ""+"\r"
	strset += "Function tClamp16SettingTemplateA()"+"\r"
	strset += "	tClamp16_FolderCheck()" + "\r"
	strset += "	String fldrSav0= GetDataFolder(1)"+"\r"
	strset += "	SetDataFolder root:Packages:tClamp16"+"\r"
	strset += ""+"\r"
	strset += "	//DAC0"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC0 = 1"+"\r"
	strset += "	Variable/G CommandSensCC_DAC0 = 1"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC1"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC1 = 1"+"\r"	
	strset += "	Variable/G CommandSensCC_DAC1 = 1"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC2"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC2 = 1"+"\r"	
	strset += "	Variable/G CommandSensCC_DAC2 = 1	"+"\r"	
	strset += ""+"\r"
	strset += "	//DAC3"+"\r"	
	strset += "	Variable/G CommandSensVC_DAC3 = 1"+"\r"
	strset += "	Variable/G CommandSensCC_DAC3 = 1"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC0"+"\r"	
	strset += "	Variable/G ADCMode0 = 0"+"\r"
	strset += "	Variable/G SealTestPulse0 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC0 VC"+"\r"
	strset += "	Variable/G ADCRangeVC0 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC0 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC0 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC0 = \"ADCVC0\""+"\r"
	strset += "	String/G UnitADCVC0 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC0 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC0 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC0 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC0 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC0 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC0 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC0 = 1"+"\r"
	strset += "	String/G LabelADCCC0 = \"ADC0 CC\""+"\r"	
	strset += "	String/G UnitADCCC0 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC0 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC0 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC0 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC1"+"\r"	
	strset += "	Variable/G ADCMode1 = 0"+"\r"
	strset += "	Variable/G SealTestPulse1 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC1 VC"+"\r"
	strset += "	Variable/G ADCRangeVC1 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC1 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC1 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC1 = \"ADC1 VC\""+"\r"
	strset += "	String/G UnitADCVC1 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC1 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC1 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC1 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC1 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC1 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC1 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC1 = 1"+"\r"
	strset += "	String/G LabelADCCC1 = \"ADC1 CC\""+"\r"	
	strset += "	String/G UnitADCCC1 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC1 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC1 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC1 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC2"+"\r"	
	strset += "	Variable/G ADCMode2 = 0"+"\r"
	strset += "	Variable/G SealTestPulse2 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC2 VC"+"\r"
	strset += "	Variable/G ADCRangeVC2 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC2 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC2 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC2 = \"ADC2 VC\""+"\r"
	strset += "	String/G UnitADCVC02= \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC2 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC2 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC2 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC2 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC2 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC2 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC2 = 1"+"\r"
	strset += "	String/G LabelADCCC2 = \"ADC2 CC\""+"\r"	
	strset += "	String/G UnitADCCC2 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC2 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC2 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC2 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC3"+"\r"	
	strset += "	Variable/G ADCMode3 = 0"+"\r"
	strset += "	Variable/G SealTestPulse3 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC3 VC"+"\r"
	strset += "	Variable/G ADCRangeVC3 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC3 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC3 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC3 = \"ADC3 VC\""+"\r"
	strset += "	String/G UnitADCVC3 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC3 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC3 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC3 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC3 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC3 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC3 = 1"+"\r"
	strset += "	String/G LabelADCCC3 = \"ADC3 CC\""+"\r"	
	strset += "	String/G UnitADCCC3 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC3 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += 	"String/G CouplingDAC_ADCCC3 = \"none\""+"\r"
	strset += 	"String/G CouplingADC_ADCCC3 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC4"+"\r"	
	strset += "	Variable/G ADCMode4 = 0"+"\r"
	strset += "	Variable/G SealTestPulse4 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC4 VC"+"\r"
	strset += "	Variable/G ADCRangeVC4 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC4 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC4 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC4 = \"ADC4 VC\""+"\r"
	strset += "	String/G UnitADCVC4 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC4 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC4 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC4 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC4 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC4 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC4 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC4 = 1"+"\r"
	strset += "	String/G LabelADCCC4 = \"ADC4 CC\""+"\r"	
	strset += "	String/G UnitADCCC4 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC4 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC4 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC4 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC5"+"\r"	
	strset += "	Variable/G ADCMode5 = 0"+"\r"
	strset += "	Variable/G SealTestPulse5 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC5 VC"+"\r"
	strset += "	Variable/G ADCRangeVC5 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC5 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC5 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC5 = \"ADC5 VC\""+"\r"
	strset += "	String/G UnitADCVC5 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC5 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC5 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC5 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC5 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC5 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC5 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC5 = 1"+"\r"
	strset += "	String/G LabelADCCC5 = \"ADC5 CC\""+"\r"	
	strset += "	String/G UnitADCCC5 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC5 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC5 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC5 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC6"+"\r"	
	strset += "	Variable/G ADCMode6 = 0"+"\r"
	strset += "	Variable/G SealTestPulse6 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC6 VC"+"\r"
	strset += "	Variable/G ADCRangeVC6 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC6 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC6 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC6 = \"ADC6 VC\""+"\r"
	strset += "	String/G UnitADCVC6 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC6 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC6 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC6 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC6 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC6 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC6 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC6 = 1"+"\r"
	strset += "	String/G LabelADCCC6 = \"ADC6 CC\""+"\r"	
	strset += "	String/G UnitADCCC6 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC6 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC6 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC6 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC7"+"\r"	
	strset += "	Variable/G ADCMode7 = 0"+"\r"
	strset += "	Variable/G SealTestPulse7 = 0.25"+"\r"	
	strset += ""+"\r"	
	strset += "	//ADC7 VC"+"\r"
	strset += "	Variable/G ADCRangeVC7 = 10"+"\r"	
	strset += "	Variable/G AmpGainADCVC7 = 1"+"\r"	
	strset += "	Variable/G ScalingFactorADCVC7 = 1e+09"+"\r"	
	strset += "	String/G LabelADCVC7 = \"ADCVC7\""+"\r"
	strset += "	String/G UnitADCVC7 = \"A\""+"\r"	
	strset += "	String/G AmpGainListADCVC7 = \"1;2;5;10;20;50;100;200;500;1000:2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCVC7 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCVC7 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	//ADC7 CC"+"\r"	
	strset += "	Variable/G ADCRangeCC7 = 10"+"\r"
	strset += "	Variable/G AmpGainADCCC7 = 1"+"\r"
	strset += "	Variable/G ScalingFactorADCCC7 = 1"+"\r"
	strset += "	String/G LabelADCCC7 = \"ADC7 CC\""+"\r"	
	strset += "	String/G UnitADCCC7 = \"V\""+"\r"	
	strset += "	String/G AmpGainListADCCC7 = \"1;2;5;10;20;50;100;200;500;1000;2000\""+"\r"	
	strset += "	String/G CouplingDAC_ADCCC7 = \"none\""+"\r"
	strset += "	String/G CouplingADC_ADCCC7 = \"none\""+"\r"
	strset += ""+"\r"	
	strset += "	tClamp16SetChannelMode()"+"\r"	
	strset += ""+"\r"	
	strset += "	tClamp16PrepWindows(bitDAC, bitADC) // tClamp16PrepWindows(bitDAC, bitADC)"+"\r"	
	strset += "	SetDataFolder fldrSav0"+"\r"
	strset += "	tClamp16SetChannelMode()"+"\r"	
	strset += ""+"\r"	
	strset += ""+"\r"		
	strset += "End"+"\r"
	strset += ""+"\r"
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strset + "\r"
end

Function  tClamp16HelpNote()
	NewNotebook/F=0
	String strhelp =""
	strhelp += "0. Click tClamp16Initialize						(Menu -> tClamp16 -> Initialize -> tClamp16Initialize)"+"\r"
	strhelp += "1. Select setting.ipf				 			(Menu -> tClamp16 -> Setting -> any setting)"+"\r"
	strhelp += "2. Select oscillo protocol.ipf		 			(Menu -> tClamp16 -> Oscillo Protocol)"+"\r"
	strhelp += "3. If you need it, select stimulator protocol.ipf 	(Menu -> tClamp16 -> Stimulator Protocol)"+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	strhelp += ""+"\r"
	Notebook $WinName(0, 16) selection={endOfFile, endOfFile}
	Notebook $WinName(0, 16) text = strhelp + "\r"
end

Function tClamp16SetChannelMode()
	Variable i = 0
	
	For(i = 0; i < 8; i += 1)
		NVAR ADCMode = $("root:Packages:tClamp16:ADCMode" + Num2str(i))
		tClamp16ModeSwitch(i, ADCMode)
	endfor
end

Function tClamp16PrepWindows(bitDAC, bitADC)
	Variable bitDAC, bitADC
	
	Variable i = 0
	For(i = 0; i < 8; i += 1)
		If(bitDAC & 2^i)
			CheckBox $("ChecktClampDAC" + Num2str(i) + "_tab0"), win = tClamp16MainControlPanel, value = 1
			tClamp16MainDACCheckProc("ChecktClampDAC" + Num2str(i),1)
		endif
		
		If(bitADC & 2^i)
			CheckBox $("ChecktClampADC" + Num2str(i) + "_tab0"), win = tClamp16MainControlPanel, value = 1
			tClamp16MainADCCheckProc("ChecktClampADC"+ Num2str(i),1)
			
			CheckBox $("ChecktClampOscilloADC" + Num2str(i) + "_tab1"), win = tClamp16MainControlPanel, value = 1
			tClamp16OscilloCheckProc("ChecktClampOscilloADC" + Num2str(i),1)
			
			CheckBox $("ChecktClampMainSealADC" + Num2str(i) + "_tab2"), win = tClamp16MainControlPanel, value = 1
			tClamp16MainSealTestCheckProc("ChecktClampMainSealADC" + Num2str(i),1)
		endif
	endFor
end

///////////////////////////////////////////////////////////////////
// Main Control Panel

Function tClamp16_MainControlPanel()
	NewPanel /N=tClamp16MainControlPanel/W=(310,56,1039,159)
	TabControl TabtClampMain,pos={6,4},size={720,96},proc=tClamp16MainTabProc
	TabControl TabtClampMain,tabLabel(0)="DAC/ADC",tabLabel(1)="Oscillo Protocol"
	TabControl TabtClampMain,tabLabel(2)="Seal Test",tabLabel(3)="Stimulator"
	TabControl TabtClampMain,tabLabel(4)="FIFO"
	TabControl TabtClampMain,value= 0
	
//tab0 (DAC/ADC)
	GroupBox GrouptClampMainDACs_tab0,pos={40,28},size={156,65},title="DAC"
	CheckBox ChecktClampDAC0_tab0,pos={60,50},size={24,14},proc=tClamp16MainDACCheckProc,title="0",variable = root:Packages:tClamp16:MainCheckDAC0
	CheckBox ChecktClampDAC1_tab0,pos={90,50},size={24,14},proc=tClamp16MainDACCheckProc,title="1",variable = root:Packages:tClamp16:MainCheckDAC1
	CheckBox ChecktClampDAC2_tab0,pos={120,50},size={24,14},proc=tClamp16MainDACCheckProc,title="2",variable = root:Packages:tClamp16:MainCheckDAC2
	CheckBox ChecktClampDAC3_tab0,pos={150,50},size={24,14},proc=tClamp16MainDACCheckProc,title="3",variable = root:Packages:tClamp16:MainCheckDAC3
	Button BtDACShow_tab0,pos={45,68},size={40,20},proc=tClamp16DACADCShowHide,title="Show"
	Button BtDACHide_tab0,pos={90,68},size={40,20},proc=tClamp16DACADCShowHide,title="Hide"
	ValDisplay ValdisptClampDACBit_tab0,pos={139,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:DACBit"
	
	GroupBox GrouptClampMainADCs_tab0,pos={208,28},size={274,65},title="ADC"	
	CheckBox ChecktClampADC0_tab0,pos={220,50},size={24,14},proc=tClamp16MainADCCheckProc,title="0",variable = root:Packages:tClamp16:MainCheckADC0
	CheckBox ChecktClampADC1_tab0,pos={250,50},size={24,14},proc=tClamp16MainADCCheckProc,title="1",variable = root:Packages:tClamp16:MainCheckADC1
	CheckBox ChecktClampADC2_tab0,pos={280,50},size={24,14},proc=tClamp16MainADCCheckProc,title="2",variable = root:Packages:tClamp16:MainCheckADC2
	CheckBox ChecktClampADC3_tab0,pos={310,50},size={24,14},proc=tClamp16MainADCCheckProc,title="3",variable = root:Packages:tClamp16:MainCheckADC3
	CheckBox ChecktClampADC4_tab0,pos={340,50},size={24,14},proc=tClamp16MainADCCheckProc,title="4",variable = root:Packages:tClamp16:MainCheckADC4
	CheckBox ChecktClampADC5_tab0,pos={370,50},size={24,14},proc=tClamp16MainADCCheckProc,title="5",variable = root:Packages:tClamp16:MainCheckADC5
	CheckBox ChecktClampADC6_tab0,pos={400,50},size={24,14},proc=tClamp16MainADCCheckProc,title="6",variable = root:Packages:tClamp16:MainCheckADC6
	CheckBox ChecktClampADC7_tab0,pos={430,50},size={24,14},proc=tClamp16MainADCCheckProc,title="7",variable = root:Packages:tClamp16:MainCheckADC7
	Button BtADCShow_tab0,pos={245,68},size={40,20},proc=tClamp16DACADCShowHide,title="Show"
	Button BtADCHide_tab0,pos={290,68},size={40,20},proc=tClamp16DACADCShowHide,title="Hide"
	ValDisplay ValdisptClampADCBit_tab0,pos={415,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:ADCBit"
	
	GroupBox GrouptClampMainDigital1_tab0,pos={496,28},size={220,65},title="DigitalOut"
	CheckBox CktClampDO1Bit0_tab0,pos={540,50},size={24,14},proc=tClamp16CheckProcDigitalOutBit,title="0",variable= root:Packages:tClamp16:DigitalOutCheck0,mode=0
	CheckBox CktClampDO1Bit1_tab0,pos={570,50},size={24,14},proc=tClamp16CheckProcDigitalOutBit,title="1",variable= root:Packages:tClamp16:DigitalOutCheck1,mode=0
	CheckBox CktClampDO1Bit2_tab0,pos={600,50},size={24,14},proc=tClamp16CheckProcDigitalOutBit,title="2",variable= root:Packages:tClamp16:DigitalOutCheck2,mode=0
	CheckBox CktClampDO1Bit3_tab0,pos={630,50},size={24,14},proc=tClamp16CheckProcDigitalOutBit,title="3",variable= root:Packages:tClamp16:DigitalOutCheck3,mode=0
	ValDisplay ValdisptClampDO1Bit_tab0,pos={575,74},size={50,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:DigitalOutBit"

//tab1 (Oscillo Protocol)
	TitleBox TitletClampOscillo_tab1,pos={11,25},size={43,20},title="Oscillo", frame = 0
	CheckBox ChecktClampOscilloADC0_tab1,pos={58,24},size={24,14},proc=tClamp16OscilloCheckProc,title="0",variable = root:Packages:tClamp16:OscilloTestCheckADC0
	CheckBox ChecktClampOscilloADC1_tab1,pos={88,24},size={24,14},proc=tClamp16OscilloCheckProc,title="1",variable = root:Packages:tClamp16:OscilloTestCheckADC1
	CheckBox ChecktClampOscilloADC2_tab1,pos={118,24},size={24,14},proc=tClamp16OscilloCheckProc,title="2",variable = root:Packages:tClamp16:OscilloTestCheckADC2
	CheckBox ChecktClampOscilloADC3_tab1,pos={148,24},size={24,14},proc=tClamp16OscilloCheckProc,title="3",variable = root:Packages:tClamp16:OscilloTestCheckADC3
	CheckBox ChecktClampOscilloADC4_tab1,pos={178,24},size={24,14},proc=tClamp16OscilloCheckProc,title="4",variable = root:Packages:tClamp16:OscilloTestCheckADC4
	CheckBox ChecktClampOscilloADC5_tab1,pos={208,24},size={24,14},proc=tClamp16OscilloCheckProc,title="5",variable = root:Packages:tClamp16:OscilloTestCheckADC5
	CheckBox ChecktClampOscilloADC6_tab1,pos={238,24},size={24,14},proc=tClamp16OscilloCheckProc,title="6",variable = root:Packages:tClamp16:OscilloTestCheckADC6
	CheckBox ChecktClampOscilloADC7_tab1,pos={268,24},size={24,14},proc=tClamp16OscilloCheckProc,title="7",variable = root:Packages:tClamp16:OscilloTestCheckADC7
	ValDisplay ValdisptClampOscilloBit_tab1,pos={312,25},size={46,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:OscilloBit"

	Button BtEditRecordingCheckADCs_tab1,pos={8,37},size={45,16},proc=tClamp16EditRecordingChecks,title="Record"
	CheckBox ChecktClampRecordingADC0_tab1,pos={58,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="0",variable= root:Packages:tClamp16:RecordingCheckADC0,mode=1
	CheckBox ChecktClampRecordingADC1_tab1,pos={88,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="1",variable= root:Packages:tClamp16:RecordingCheckADC1,mode=1
	CheckBox ChecktClampRecordingADC2_tab1,pos={118,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="2",variable= root:Packages:tClamp16:RecordingCheckADC2,mode=1
	CheckBox ChecktClampRecordingADC3_tab1,pos={148,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="3",variable= root:Packages:tClamp16:RecordingCheckADC3,mode=1
	CheckBox ChecktClampRecordingADC4_tab1,pos={178,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="4",variable= root:Packages:tClamp16:RecordingCheckADC4,mode=1
	CheckBox ChecktClampRecordingADC5_tab1,pos={208,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="5",variable= root:Packages:tClamp16:RecordingCheckADC5,mode=1
	CheckBox ChecktClampRecordingADC6_tab1,pos={238,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="6",variable= root:Packages:tClamp16:RecordingCheckADC6,mode=1
	CheckBox ChecktClampRecordingADC7_tab1,pos={268,39},size={24,14},proc=tClamp16CheckProcRecordingBit,title="7",variable= root:Packages:tClamp16:RecordingCheckADC7,mode=1
	ValDisplay ValdispRecordingChBit_tab1,pos={312,39},size={46,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:RecordingBit"

	TitleBox TitletClampProtocolName_tab1,pos={11,54},size={32,20},variable= root:Packages:tClamp16:SelectedProtocol
	Button BttClampProtocolRun_tab1,pos={150,54},size={40,20},proc=tClamp16ProtocolRun,title="Run"
	Button BttClampProtocolCont_tab1,pos={190,54},size={40,20},proc=tClamp16ProtocolRun,title="Cont."
	Button BttClampBackGStop_tab1,pos={230,54},size={40,20},proc=tClamp16BackGStop,title="Stop"
	Button BttClampProtocolSave_tab1,pos={270,54},size={40,20},proc=tClamp16ProtocolSave,title="Save"
	Button BttClampClearWaves_tab1,pos={310,54},size={40,20},proc=tClamp16ClearTempWaves,title="Clear"
	Button BttClampEditProtocol_tab1,pos={350,54},size={40,20},proc=tClamp16EditProtocol,title="Edit"
	Button BtResetNumTrial_tab1,pos={396,54},size={30,20},proc=tClamp16ResetNumTrial,title="Trial",fColor=(48896,52992,65280)
	SetVariable SetvartClampNumTrial_tab1,pos={430,55},size={40,16},title=" ",limits={0,inf,1},value= root:Packages:tClamp16:NumTrial
	ValDisplay ValdisptClampOscilloCount_tab1,pos={478,56},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:OscilloCounter"
	SetVariable SetvarOscilloCounterLimit_tab1,pos={587,54},size={130,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp16:OscilloCounterLimit
	
	TitleBox TitleDACSeq_tab1,pos={12,80},size={54,12},title="DAC/ADC",frame=0
	Button EditITC16Seq_tab1,pos={72,75},size={30,20},proc=tClamp16EditITC16Seq,title="Seq"
	TitleBox TitleDispDACSeq_tab1,pos={107,75},size={14,20},variable= root:Packages:tClamp16:StrITC16SeqDAC
	TitleBox TitleDispADCSeq_tab1,pos={176,75},size={14,20},variable= root:Packages:tClamp16:StrITC16SeqADC
	SetVariable SetvarITC16Perid_tab1,pos={245,77},size={70,16},limits={5,65535,1},proc=tClamp16SetVarProcOscilloFreq,title="Perid",value= root:Packages:tClamp16:OscilloITC16Period
	ValDisplay ValdisptClampOscilloFreq_tab1,pos={323,78},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:OscilloFreq"
	SetVariable SetvarOscilloWaveReD_tab1,pos={428,76},size={100,16},proc=tClamp16OscilloReDimension,title="npnts",value= root:Packages:tClamp16:OscilloSamplingNpnts
	ValDisplay ValdispAcqTime_tab1,pos={534,79},size={125,13},title="AcqTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:OscilloAcqTime"

	Button BtOSCShow_tab1,pos={367,28},size={20,20},proc=tClamp16OSCShowHide,title="S"
	Button BtOSCHide_tab1,pos={393,28},size={20,20},proc=tClamp16OSCShowHide,title="H"
	SetVariable SetvartClampOscilloISI_tab1,pos={425, 23},size={100,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp16:OscilloISI
	CheckBox CheckStimulator_tab1,pos={423,39},size={70,14},proc=tClamp16CheckProcITC16Flags,title="Stimulator",variable= root:Packages:tClamp16:StimulatorCheck
	CheckBox CheckExtTrig_tab1,pos={532,32},size={55,14},proc=tClamp16CheckProcITC16Flags,title="ExtTrig",variable= root:Packages:tClamp16:OscilloITC16ExtTrig
	CheckBox CheckOutputEnable_tab1,pos={595,32},size={52,14},proc=tClamp16CheckProcITC16Flags,title="Output",variable= root:Packages:tClamp16:OscilloITC16Output
	CheckBox CheckITC16Overflow_tab1,pos={654,32},size={63,14},proc=tClamp16CheckProcITC16Flags,title="Overflow",variable= root:Packages:tClamp16:OscilloITC16Overflow

//tab2 (Seal Test)
	CheckBox ChecktClampMainSealADC0_tab2,pos={15,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="0",variable= root:Packages:tClamp16:SealTestCheckADC0
	CheckBox ChecktClampMainSealADC1_tab2,pos={45,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="1",variable= root:Packages:tClamp16:SealTestCheckADC1
	CheckBox ChecktClampMainSealADC2_tab2,pos={75,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="2",variable= root:Packages:tClamp16:SealTestCheckADC2
	CheckBox ChecktClampMainSealADC3_tab2,pos={110,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="3",variable= root:Packages:tClamp16:SealTestCheckADC3
	CheckBox ChecktClampMainSealADC4_tab2,pos={140,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="4",variable= root:Packages:tClamp16:SealTestCheckADC4
	CheckBox ChecktClampMainSealADC5_tab2,pos={170,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="5",variable= root:Packages:tClamp16:SealTestCheckADC5
	CheckBox ChecktClampMainSealADC6_tab2,pos={200,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="6",variable= root:Packages:tClamp16:SealTestCheckADC6
	CheckBox ChecktClampMainSealADC7_tab2,pos={230,30},size={24,14},proc=tClamp16MainSealTestCheckProc,title="7",variable= root:Packages:tClamp16:SealTestCheckADC7
	ValDisplay ValdisptClampSealTestBit_tab2,pos={262,30},size={45,13},title="bit",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:SealTestBit"
	SetVariable SetvartClampSealTestISI_tab2,pos={325,31},size={100,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp16:SealTestISI
	CheckBox CheckTrigOut_tab2,pos={440,32},size={56,14},proc=tClamp16CheckSealTrigOut,title="TrigOut",variable= root:Packages:tClamp16:SealITC16Trigout
	CheckBox CheckExtTrig_tab2,pos={510,32},size={55,14},proc=tClamp16CheckSealITC16Flags,title="ExtTrig",variable= root:Packages:tClamp16:SealITC16ExtTrig
	CheckBox CheckOutputEnable_tab2,pos={580,32},size={52,14},proc=tClamp16CheckSealITC16Flags,title="Output",variable= root:Packages:tClamp16:SealITC16Output
	CheckBox CheckITC16Overflow_tab2,pos={650,32},size={63,14},proc=tClamp16CheckSealITC16Flags,title="Overflow",variable= root:Packages:tClamp16:SealITC16Overflow

	Button BttClampMainSealTestRun_tab2,pos={15,48},size={50,20},proc=tClamp16SealTestBGRun,title="Run"
	Button BttClampMainSealTestAbort_tab2,pos={65,48},size={50,20},proc=tClamp16BackGStop,title="Abort"
	Button BttClampMainSealTestShow_tab2,pos={115,48},size={50,20},proc=tClamp16MainSealShowHide,title="Show"
	Button BttClampMainSealTestHide_tab2,pos={165,48},size={50,20},proc=tClamp16MainSealShowHide,title="Hide"
	ValDisplay ValdisptClampSealCount_tab2,pos={430,52},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:SealTestCounter"
	SetVariable SetvarSealCounterLimit_tab2,pos={546,50},size={150,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp16:SealTestCounterLimit

	TitleBox TitleDACSeq_tab2,pos={12,80},size={54,12},title="DAC/ADC",frame=0
	Button EditITC16Seq_tab2,pos={72,75},size={30,20},proc=tClamp16EditSealITC16Seq,title="Seq"
	TitleBox TitleDispDACSeq_tab2,pos={107,75},size={14,20},variable= root:Packages:tClamp16:SealITC16SeqDAC
	TitleBox TitleDispADCSeq_tab2,pos={176,75},size={14,20},variable= root:Packages:tClamp16:SealITC16SeqADC
	SetVariable SetvarITC16Perid_tab2,pos={245,77},size={70,16},proc=tClamp16SetVarProcSealFreq,title="Perid",limits={5,65535,1},value= root:Packages:tClamp16:SealITC16Period
	ValDisplay ValdisptClampSealFreq_tab2,pos={323,78},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:SealTestFreq"
	SetVariable SetvarSealWaveReD_tab2,pos={428,76},size={100,16},proc=tClamp16SealRedimension,title="npnts",value= root:Packages:tClamp16:SealSamplingNpnts
	ValDisplay ValdispAcqTime_tab2,pos={534,79},size={125,13},title="AcqTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:SealAcqTime"

//tab3 (Stimulator)
	ValDisplay ValdisptClampStimCount_tab3,pos={12,27},size={100,13},title="Counter",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:StimulatorCounter"
	SetVariable SetvarStimCounterLimit_tab3,pos={12,40},size={118,16},title="CounterLimit",limits={0,inf,1},value= root:Packages:tClamp16:StimulatorCounterLimit
	SetVariable SetvartClampStimISI_tab3,pos={12,57},size={118,16},title="ISI (tick)",limits={1,inf,1},value= root:Packages:tClamp16:StimulatorISI
	Button BttClampStimulatorRun_tab3,pos={10,74},size={40,20},proc=tClamp16StimulatorRun,title="Run"
	Button BttClampBackGStop_tab3,pos={50,74},size={40,20},proc=tClamp16BackGStop,title="Stop"
	Button BttClampStimulatorReset_tab3,pos={90,74},size={40,20},proc=tClamp16StimulatorReset,title="Reset"
	SetVariable SetvarITC16Perid_tab3,pos={135,22},size={70,16},proc=tClamp16SetVarProcStimulator,title="Perid",limits={5,65535,1},value= root:Packages:tClamp16:StimulatorITC16Period
	ValDisplay ValdisptClampStimFreq_tab3,pos={135,40},size={100,13},title="Frequency",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:StimulatorFreq"
	SetVariable SetvarStimulatorReD_tab3,pos={135,57},size={100,16},proc=tClamp16SetVarProcStimulator,title="npnts",value= root:Packages:tClamp16:StimulatorSamplingNpnts
	SetVariable SetvarStimulatorAcqTime_tab3,pos={135,76},size={100,16},proc=tClamp16SetVarProcStimulator,title="Time (s)",value= root:Packages:tClamp16:StimulatorAcqTime

	PopupMenu PopupStimulatorCh0_tab3,pos={243,23},size={99,20},proc=tClamp16PopMenuProcStimulator,title="Ch0 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp16:StimulatorTrig0"
	PopupMenu PopupStimulatorCh1_tab3,pos={243,41},size={99,20},proc=tClamp16PopMenuProcStimulator,title="Ch1 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp16:StimulatorTrig1"
	PopupMenu PopupStimulatorCh2_tab3,pos={243,59},size={99,20},proc=tClamp16PopMenuProcStimulator,title="Ch2 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp16:StimulatorTrig2"
	PopupMenu PopupStimulatorCh3_tab3,pos={243,77},size={99,20},proc=tClamp16PopMenuProcStimulator,title="Ch3 Trig",mode=1,popvalue="main",value= #"root:Packages:tClamp16:StimulatorTrig3"
	
	SetVariable SetvartClampStimDelay0_tab3,pos={362,25},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorDelay0
	SetVariable SetvartClampStimDelay1_tab3,pos={362,42},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorDelay1
	SetVariable SetvartClampStimDelay2_tab3,pos={362,59},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorDelay2
	SetVariable SetvartClampStimDelay3_tab3,pos={362,76},size={90,16},title="Del (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorDelay3

	SetVariable SetvartClampStimInterval0_tab3,pos={458,25},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorInterval0
	SetVariable SetvartClampStimInterval1_tab3,pos={458,42},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorInterval1
	SetVariable SetvartClampStimInterval2_tab3,pos={458,59},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorInterval2
	SetVariable SetvartClampStimInterval3_tab3,pos={458,76},size={90,16},title="ISI (s)",limits={0,inf,1e-03},value= root:Packages:tClamp16:StimulatorInterval3
	
	SetVariable SetvartClampStimTrain0_tab3,pos={552,25},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp16:StimulatorTrain0
	SetVariable SetvartClampStimTrain1_tab3,pos={552,42},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp16:StimulatorTrain1
	SetVariable SetvartClampStimTrain2_tab3,pos={552,59},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp16:StimulatorTrain2
	SetVariable SetvartClampStimTrain3_tab3,pos={552,76},size={70,16},title="Train",limits={0,inf,1},value= root:Packages:tClamp16:StimulatorTrain3

	SetVariable SetvartClampStimDuration0_tab3,pos={626,25},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp16:StimulatorDuration0
	SetVariable SetvartClampStimDuration1_tab3,pos={626,42},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp16:StimulatorDuration1
	SetVariable SetvartClampStimDuration2_tab3,pos={626,59},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp16:StimulatorDuration2
	SetVariable SetvartClampStimDuration3_tab3,pos={626,76},size={95,16},title="Dur (s)",limits={0,inf,1e-05},value= root:Packages:tClamp16:StimulatorDuration3

//tab4 (FIFO)
	Button BttClampMainFIFOGraph_tab4,pos={344,33},size={50,20},proc=tClamp16DisplayHideFIFO,title="FIFO"

//
	ModifyControlList ControlNameList("tClamp16MainControlPanel", ";", "!*_tab0") disable = 1
	ModifyControl TabtClampMain disable=0
end

Function tClamp16MainTabProc(ctrlName,tabNum) : TabControl
	String ctrlName
	Variable tabNum
	String controlsInATab= ControlNameList("tClamp16MainControlPanel",";","*_tab*")
	String curTabMatch="*_tab*"+Num2str(tabNum)
	String controlsInCurTab= ListMatch(controlsInATab, curTabMatch)
	String controlsInOtherTab= ListMatch(controlsInATab, "!"+curTabMatch)
	ModifyControlList controlsInCurTab disable = 0 //show
	ModifyControlList controlsInOtherTab disable = 1 //hide
	return 0
End

Function tClamp16_DispMainControlPanel()
	If(WinType("tClamp16MainControlPanel") == 7)
		DoWindow/HIDE = ? $("tClamp16MainControlPanel")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp16MainControlPanel")
		else
			DoWindow/HIDE = 0/F $("tClamp16MainControlPanel")
		endif
	else	
		tClamp16_MainControlPanel()
	endif
End

Function tClamp16_HideMainControlPanel()
	If(WinType("tClamp16MainControlPanel"))
		DoWindow/HIDE = 1 $("tClamp16MainControlPanel")
	endif
End

Function tClamp16MainDACCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	Variable num_channel

	sscanf ctrlName, "ChecktClampDAC%f", num_channel
	If(checked)
		If(WinType("tClamp16DAC"+Num2str(num_channel)) == 7)
			DoWindow/HIDE = ? $("tClamp16DAC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp16DAC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp16DAC"+Num2str(num_channel))
			endif
		else	
			tClamp16NewDACPanel(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp16DAC"+Num2str(num_channel))
	endif
	
	tClamp16BitUpdate("root:Packages:tClamp16:MainCheckDAC", "root:Packages:tClamp16:DACbit", 4)
End

Function tClamp16NewDACPanel(num_channel)
	Variable num_channel
	NewPanel/N=$("tClamp16DAC"+Num2str(num_channel))/W=(18+27*num_channel,595-20*num_channel,345+27*num_channel,691-20*num_channel)
	ValDisplay $("ValdisptClampValueVoltDAC"+Num2str(num_channel)),pos={11,9},size={75,13},title="Volt",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp16:DACValueVolt"+Num2str(num_channel))
	SetVariable $("SetvartClampCommandSensVCDAC" +Num2str(num_channel)),pos={11,31},size={250,16},title="VC Command Sensitivity (mV/V)",value= $("root:Packages:tClamp16:CommandSensVC_DAC" + Num2str(num_channel))
	SetVariable $("SetvartClampCommandSensCCDAC" +Num2str(num_channel)),pos={11,52},size={250,16},title="CC Command Sensitivity (pA/V)",value= $("root:Packages:tClamp16:CommandSensCC_DAC" +Num2str(num_channel))
	SetVariable $("SetvartClampSetValueDAC" +Num2str(num_channel)),pos={102,7},size={50,16},proc=tClamp16SetVarProcSetVoltDAC,title=" ",limits={-10,10,0},value= $("root:Packages:tClamp16:DACValueVolt"+Num2str(num_channel))
	Slider $("SlidertClampSetDAC"+Num2str(num_channel)),pos={273,2},size={59,92},proc=tClamp16SetDACSliderProc,limits={-10,10,0.01},variable= $("root:Packages:tClamp16:DACValueVolt" +Num2str(num_channel))
End

Proc tClamp16SetVarProcSetVoltDAC(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	Variable num_channel
	num_channel = tClamp16sscanf(ctrlName, "SetvartClampSetValueDAC%f")
	ITC16SetDAC num_channel, varNum
EndMacro

Function tClamp16sscanf(inputstr, formatstr)
	String inputstr, formatstr
	Variable varReturn
	sscanf inputstr, formatstr, varReturn
	return varReturn
end

Function tClamp16DisplayHideFIFO(ctrlName) : ButtonControl
	String ctrlName
	If(WinType("tClamp16FIFOout") == 1)
		DoWindow/HIDE = ? $("tClamp16FIFOout")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp16FIFOout")
		else
			DoWindow/HIDE = 0/F $("tClamp16FIFOout")
		endif
	else	
		Display/W=(20.25,157.25,249,365.75)/N=$("tClamp16FIFOout") $("root:Packages:tClamp16:FIFOout")
	endif
	
	If(WinType("tClamp16FIFOin") == 1)
		DoWindow/HIDE = ? $("tClamp16FIFOin")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp16FIFOin")
		else
			DoWindow/HIDE = 0/F $("tClamp16FIFOin")
		endif
	else	
		Display/W=(261,157.25,489,365.75)/N=$("tClamp16FIFOin") $("root:Packages:tClamp16:FIFOin")
	endif
	
	If(WinType("tClamp16DigitalOut") == 1)
		DoWindow/HIDE = ? $("tClamp16DigitalOut")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp16DigitalOut")
		else
			DoWindow/HIDE = 0/F $("tClamp16DigitalOut")
		endif
	else	
		Display/W=(501,157.25,729,365.75)/N=$("tClamp16DigitalOut") $("root:Packages:tClamp16:DigitalOut")
	endif
End

// Main
///////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
//DAC panel

Proc tClamp16SetDACSliderProc(ctrlName,sliderValue,event) : SliderControl
	String ctrlName
	Variable sliderValue
	Variable event	// bit field: bit 0: value set, 1: mouse down, 2: mouse up, 3: mouse moved
	Variable num_channel
	num_channel = tClamp16sscanf(ctrlName, "SlidertClampSetDAC%f")
	
	ITC16SetDAC num_channel, sliderValue
endMacro

Function tClamp16ITC16SetDAC(num_channel, volt)
	Variable num_channel, volt
	NVAR DACValueVolt = $("root:Packages:tClamp16:DACValueVolt" +Num2str(num_channel))
	tClamp16_Execute("ITC16SetDAC num_channel, volt")
	DACValueVolt = volt
EndMacro

Function tClamp16MainADCCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	Variable num_channel

	sscanf ctrlName, "ChecktClampADC%f", num_channel
	If(checked)
		If(WinType("tClamp16ADC"+Num2str(num_channel)) == 7)
			DoWindow/HIDE = ? $("tClamp16ADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp16ADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp16ADC"+Num2str(num_channel))
			endif
		else	
			tClamp16NewADCPanel(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp16ADC"+Num2str(num_channel))
	endif
	
	tClamp16BitUpdate("root:Packages:tClamp16:MainCheckADC", "root:Packages:tClamp16:ADCbit", 8)
End

Function tClamp16NewADCPanel(num_channel)
	Variable num_channel
	NewPanel/N=$("tClamp16ADC"+Num2str(num_channel))/W=(98+27*num_channel,646-20*num_channel,398+27*num_channel,846-20*num_channel)
	ValDisplay $("ValdisptClampADCValueV"+Num2str(num_channel)),pos={15,5},size={75,13},title="Volt",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp16:ADCValueVolt"+Num2str(num_channel))
	ValDisplay $("ValdisptClampADCValueP"+Num2str(num_channel)),pos={145,5},size={75,13},title="Point",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp16:ADCValuePoint"+Num2str(num_channel))
	TitleBox $("TitletClampADCLabel" + Num2str(num_channel)),pos={8,23},size={38,20},fSize=12,variable= $("root:Packages:tClamp16:LabelADC" + Num2str(num_channel))
	Button $("BttClampADCVCSwitch" + Num2str(num_channel)),pos={130,22},size={50,20},proc=tClamp16VClampSwitch,title="VClamp"
	Button $("BttClampADCCCSwitch" + Num2str(num_channel)),pos={230,22},size={50,20},proc=tClamp16CClampSwitch,title="CClamp"
	ValDisplay $("ValdisptClampADCRange"+ Num2str(num_channel)), pos={9,59},size={80,13},title="Range (V)", limits={0,0,0},barmisc={0,1000}, value= #("root:Packages:tClamp16:ADCRange"+Num2str(num_channel))
	PopupMenu $("PopuptClampADCRange"+ Num2str(num_channel)), pos={92,55},size={43,20},proc=tClamp16PopMenuProcADCRange, mode=1, popvalue = "10", value=#"\"10\""
	SetVariable $("SetvartClampInputOffset" + Num2str(num_channel)),pos={163,57},size={135,16},title="Input Off (V)",limits={-10,10,0.001},value= $("root:Packages:tClamp16:InputOffset" + Num2str(num_channel))
	SetVariable $("SetvartClampADCOffset" + Num2str(num_channel)),pos={163,77},size={135,16},title="ADC Off (V)",limits={-10,10,0.001},value= $("root:Packages:tClamp16:ADCOffset" + Num2str(num_channel))
	ValDisplay $("ValdisptClampAmpGain"+Num2str(num_channel)),pos={8,81},size={80,13},title="AmpGain",limits={0,0,0},barmisc={0,1000},value= #("root:Packages:tClamp16:AmpGainADC"+Num2str(num_channel))
	PopupMenu $("PopuptClampAmpGain"+Num2str(num_channel)),pos={92,77},size={56,20},proc=tClamp16PopMenuProcAmpGain,mode=1,popvalue="1",value= #("root:Packages:tClamp16:AmpGainListADC"+ Num2str(num_channel))
	SetVariable $("SetvartClampScalingADC" +Num2str(num_channel)),pos={10,100},size={205,16},proc=tClamp16SetVarProcScalingFactor,title="ScalingFactor (V/A or V/V)",value= $("root:Packages:tClamp16:ScalingFactorADC"+Num2str(num_channel))
	TitleBox $("TitletClampUnitADC" + Num2str(num_channel)),pos={10,119},size={16,20},variable= $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampUnitADC" + Num2str(num_channel)),pos={37,119},size={71,20},proc=tClamp16PopMenuProcUnitADC,title="Unit",mode=1,popvalue="A",value= #"\"A;V\""
	TitleBox $("TitletClampCoupling" + Num2str(num_channel)),pos={9,145},size={32,20},variable= $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampCoupling" + Num2str(num_channel)),pos={48,145},size={134,20},proc=tClamp16PopMenuProcCouplingDAC,title="CouplingDAC",mode=1,popvalue="none",value= #"\"none;0;1;2;3\""
	TitleBox $("TitletClampCouplingADC" + Num2str(num_channel)),pos={9,168},size={32,20},variable= $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
	PopupMenu $("PopuptClampCouplingADC" + Num2str(num_channel)),pos={48,168},size={134,20},proc=tClamp16PopMenuProcCouplingADC,title="CouplingADC",mode=1,popvalue="none",value= #"\"none;0;1;2;3;4;5;6;7\""
End

Function tClamp16PopMenuProcADCRange(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampADCRange%f", num_channel
	NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+ Num2str(num_channel))
	ADCRange = Str2Num(popStr)
//	tClamp16SetADCRange(num_channel, ADCRange)
End

Function tClamp16PopMenuProcAmpGain(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampAmpGain%f", num_channel
	NVAR AmpGain = $("root:Packages:tClamp16:AmpGainADC"+ Num2str(num_channel))
	AmpGain = Str2Num(popStr)
End

Function tClamp16SetVarProcScalingFactor(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	Variable num_channel
	sscanf ctrlName, "SetvartClampScalingADC%f", num_channel
	NVAR Scaling = $("root:Packages:tClamp16:ScalingFactorADC"+Num2str(num_channel))
	Scaling = varNum
End

Function tClamp16PopMenuProcUnitADC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	Variable num_channel
	sscanf ctrlName, "PopuptClampUnitADC%f", num_channel
	SVAR Unit = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Unit = popStr
End

Function tClamp16PopMenuProcCouplingDAC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampCoupling%f", num_channel
	SVAR Coupling = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(num_channel))
	Coupling = popStr
End

Function tClamp16PopMenuProcCouplingADC(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	Variable num_channel
	sscanf ctrlName, "PopuptClampCouplingADC%f", num_channel
	SVAR Coupling = $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
	Coupling = popStr
End

Function tClamp16ModeSwitch(num_channel, mode)
	Variable num_channel, mode
	If(mode)
		tClamp16CClampSwitch("BttClampADCCCSwitch"+Num2str(num_channel))
	else
		tClamp16VClampSwitch("BttClampADCVCSwitch"+Num2str(num_channel))
	endif
end

Function tClamp16VClampSwitch(ctrlName) : ButtonControl
	String ctrlName
	Variable num_channel
	sscanf ctrlName, "BttClampADCVCSwitch%f", num_channel
	
	NVAR ADCMode = $("root:Packages:tClamp16:ADCMode" +Num2str(num_channel))
	
	NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+Num2str(num_channel))
	NVAR AmpGainADC =$("root:Packages:tClamp16:AmpGainADC"+Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" +Num2str(num_channel))
	SVAR LabelADC = $("root:Packages:tClamp16:LabelADC" + Num2str(num_channel))
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	SVAR AmpGainListADC = $("root:Packages:tClamp16:AmpGainListADC" + Num2str(num_channel))
	SVAR CouplingDAC_ADC = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(num_channel))
	SVAR CouplingADC_ADC = $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
	
	NVAR ADCRangeVC = $("root:Packages:tClamp16:ADCRangeVC"+Num2str(num_channel))
	NVAR AmpGainADCVC =$("root:Packages:tClamp16:AmpGainADCVC"+Num2str(num_channel))
	NVAR ScalingFactorADCVC = $("root:Packages:tClamp16:ScalingFactorADCVC" +Num2str(num_channel))
	SVAR LabelADCVC = $("root:Packages:tClamp16:LabelADCVC" + Num2str(num_channel))
	SVAR UnitADCVC = $("root:Packages:tClamp16:UnitADCVC" + Num2str(num_channel))
	SVAR AmpGainListADCVC = $("root:Packages:tClamp16:AmpGainListADCVC" + Num2str(num_channel))
	SVAR CouplingDAC_ADCVC = $("root:Packages:tClamp16:CouplingDAC_ADCVC" + Num2str(num_channel))
	SVAR CouplingADC_ADCVC = $("root:Packages:tClamp16:CouplingADC_ADCVC" + Num2str(num_channel))
	
	ADCMode = 0
	
	ADCRange = ADCRangeVC
	AmpGainADC = AmpGainADCVC
	ScalingFactorADC = ScalingFactorADCVC
	LabelADC = LabelADCVC
	UnitADC = UnitADCVC
	AmpGainListADC = AmpGainListADCVC
	CouplingDAC_ADC = CouplingDAC_ADCVC
	CouplingADC_ADC = CouplingADC_ADCVC

	Variable ModeADCRange = tClamp16SearchMode(Num2str(ADCRange), "10")
	Variable ModeAmpGain = tClamp16SearchMode(Num2str(AmpGainADC), AmpGainListADC)
	Variable ModeUnit = tClamp16SearchMode(UnitADC, "A;V")
	Variable ModeCouplingDAC = tClamp16SearchMode(CouplingDAC_ADC, "none;0;1;2;3")
	Variable ModeCouplingADC = tClamp16SearchMode(CouplingADC_ADC, "none;0;1;2;3;4;5;6;7")
	tClamp16UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)

//	tClamp16SetADCRange(num_channel, ADCRange)
End

Function tClamp16CClampSwitch(ctrlName) : ButtonControl
	String ctrlName
	Variable num_channel
	sscanf ctrlName, "BttClampADCCCSwitch%f", num_channel
	
	NVAR ADCMode = $("root:Packages:tClamp16:ADCMode" +Num2str(num_channel))
	
	NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+Num2str(num_channel))
	NVAR AmpGainADC =$("root:Packages:tClamp16:AmpGainADC"+Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" +Num2str(num_channel))
	SVAR LabelADC = $("root:Packages:tClamp16:LabelADC" + Num2str(num_channel))
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	SVAR AmpGainListADC = $("root:Packages:tClamp16:AmpGainListADC" + Num2str(num_channel))
	SVAR CouplingDAC_ADC = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(num_channel))
	SVAR CouplingADC_ADC = $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
	
	NVAR ADCRangeCC = $("root:Packages:tClamp16:ADCRangeCC"+Num2str(num_channel))
	NVAR AmpGainADCCC =$("root:Packages:tClamp16:AmpGainADCCC"+Num2str(num_channel))
	NVAR ScalingFactorADCCC = $("root:Packages:tClamp16:ScalingFactorADCCC" +Num2str(num_channel))
	SVAR LabelADCCC = $("root:Packages:tClamp16:LabelADCCC" + Num2str(num_channel))
	SVAR UnitADCCC = $("root:Packages:tClamp16:UnitADCCC" + Num2str(num_channel))
	SVAR AmpGainListADCCC = $("root:Packages:tClamp16:AmpGainListADCCC" + Num2str(num_channel))
	SVAR CouplingDAC_ADCCC = $("root:Packages:tClamp16:CouplingDAC_ADCCC" + Num2str(num_channel))
	SVAR CouplingADC_ADCCC = $("root:Packages:tClamp16:CouplingADC_ADCCC" + Num2str(num_channel))
	
	ADCMode = 1
	
	ADCRange = ADCRangeCC
	AmpGainADC = AmpGainADCCC
	ScalingFactorADC = ScalingFactorADCCC
	LabelADC = LabelADCCC
	UnitADC = UnitADCCC
	AmpGainListADC = AmpGainListADCCC
	CouplingDAC_ADC = CouplingDAC_ADCCC
	CouplingADC_ADC = CouplingADC_ADCCC
	
	Variable ModeADCRange = tClamp16SearchMode(Num2str(ADCRange), "10")
	Variable ModeAmpGain = tClamp16SearchMode(Num2str(AmpGainADC), AmpGainListADC)
	Variable ModeUnit = tClamp16SearchMode(UnitADC, "A;V")
	Variable ModeCouplingDAC = tClamp16SearchMode(CouplingDAC_ADC, "none;0;1;2;3")
	Variable ModeCouplingADC = tClamp16SearchMode(CouplingADC_ADC, "none;0;1;2;3;4;5;6;7")
	tClamp16UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)

//	tClamp16SetADCRange(num_channel, ADCRange)
End

Function tClamp16SearchMode(searchStr, StrList)
	String SearchStr, StrList
			
	Variable i = 0
	Variable mode = 1
	String SFL
	do
		SFL = StringFromList(i, StrList)
		if(Strlen(SFL) == 0)
			break
		endif
		If(StringMatch(SearchStr, SFL))
			mode = i + 1
			break
		endIf
		i += 1
	while(1)
	
	return mode
end

Function tClamp16UpdatePopupADC(num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC)
	Variable num_channel, ModeADCRange, ModeAmpGain, ModeUnit, ModeCouplingDAC, ModeCouplingADC

	If(Wintype("tClamp16ADC" + Num2str(num_channel)) == 7)
		PopupMenu $("PopuptClampADCRange" + Num2str(num_channel)) win = $("tClamp16ADC" + Num2str(num_channel)), mode = ModeADCRange
		PopupMenu $("PopuptClampAmpGain" + Num2str(num_channel)) win = $("tClamp16ADC" + Num2str(num_channel)), mode = ModeAmpGain
		PopupMenu $("PopuptClampUnitADC" + Num2str(num_channel)) win = $("tClamp16ADC" + Num2str(num_channel)), mode = ModeUnit
		PopupMenu $("PopuptClampCoupling" + Num2str(num_channel)) win = $("tClamp16ADC" + Num2str(num_channel)), mode = ModeCouplingDAC
		PopupMenu $("PopuptClampCouplingADC" + Num2str(num_channel)) win = $("tClamp16ADC" + Num2str(num_channel)), mode = ModeCouplingADC
	endif
end

Function tClamp16DACADCShowHide(ctrlName) : ButtonControl
	String ctrlName

	String SFL = ""
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp16DAC*",";","WIN:64"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtDACShow_tab0" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BtDACHide_tab0" :
				DoWindow/HIDE = 1 $SFL
				break			
			default :
				break
		endSwitch
		i += 1
	while(1)
	 
	 i = 0
	do
		SFL = StringFromList(i, WinList("tClamp16ADC*",";","WIN:64"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtADCShow_tab0" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				break
			case "BtADCHide_tab0" :
				DoWindow/HIDE = 1 $SFL
				break			
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Proc tClamp16CheckProcDigitalOutBit(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	tClamp16BitUpdate("root:Packages:tClamp16:DigitalOutCheck", "root:Packages:tClamp16:DigitalOutBit", 4)
	ITC16WriteDigital $("root:Packages:tClamp16:DigitalOutBit")
End

//End DAC and ADC
////////////////////////////////////////////////////////////
//Oscilloscope

Function tClamp16OscilloCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	Variable num_channel

	sscanf ctrlName, "ChecktClampOscilloADC%f", num_channel
	If(checked)
		If(WinType("tClamp16OscilloADC"+Num2str(num_channel)) == 1)
			DoWindow/HIDE = ? $("tClamp16OscilloADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp16OscilloADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp16OscilloADC"+Num2str(num_channel))
			endif
		else	
			tClamp16NewOscilloADC(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp16OscilloADC"+Num2str(num_channel))
	endif
	
	tClamp16BitUpdate("root:Packages:tClamp16:OscilloTestCheckADC", "root:Packages:tClamp16:OscilloBit", 8)
End

Function tClamp16NewOscilloADC(num_channel)
	Variable num_channel

	NVAR OscilloFreq = root:Packages:tClamp16:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))

	Wave ScaledADC = $("root:Packages:tClamp16:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp16:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	Display/W=(397.5+27*num_channel,299.75-20*num_channel,674.25+27*num_channel,538.25-20*num_channel)/N=$("tClamp16OscilloADC"+Num2str(num_channel)) ScaledADC
	ModifyGraph rgb=(0,0,0)
	ModifyGraph live ($("ScaledADC" + Num2str(num_channel))) = 1
	Label left ("\\u"+UnitADC)
	ControlBar 40
	Button BtYPlus,pos={44,0},size={20,20},proc=tClamp16GraphScale,title="+"
	Button BtYMinus,pos={44,19},size={20,20},proc=tClamp16GraphScale,title="-"
	Button BtXMinus,pos={1,1},size={20,20},proc=tClamp16GraphScale,title="-"
	Button BtXPlus,pos={20,1},size={20,20},proc=tClamp16GraphScale,title="+"
	SetVariable $("SetvarExpandOSCGraph" + Num2str(num_channel)),pos={3,21},size={38,16},proc=tClamp16SetVarProcGraphExpand,title=" ",limits={0.5,8,0.5},value= $("root:Packages:tClamp16:OscilloExpand" + Num2str(num_channel))
	Button $("BttClampAscaleOSCADC"+Num2str(num_channel)),pos={68, 0},size={50,20},proc=tClamp16AscaleOSCADC,title="Auto"
	Button $("BttClampFscaleOSCADC"+Num2str(num_channel)),pos={68, 19},size={50,20},proc=tClamp16FscaleOSCADC,title="Full"
	Button $("BtClearCmdPulse" + Num2str(num_channel)),pos={120,1},size={50,20},proc=tClamp16CmdClear,title="Cmd (V)",fColor=(32768,40704,65280)
	SetVariable $("SetvarSetCmdPulse" + Num2str(num_channel)),pos={173,3},size={50,16},proc=tClamp16SetVarCheckCouplingADC,title=" ",limits={-10,10,0.01},value= $("root:Packages:tClamp16:OscilloCmdPulse" + Num2str(num_channel))
	CheckBox $("CheckOscilloCmd" + Num2str(num_channel)),pos={120,23},size={108,14},title="Command On/Off",variable= $("root:Packages:tClamp16:OscilloCmdOnOff" + Num2str(num_channel))
	CheckBox $("ChecktClampOSCLiveMode"+Num2str(num_channel)),pos={232,4},size={70,14},proc=tClamp16OSCLiveModeCheckProc,title="Live mode",value= 1
	SetDrawLayer UserFront
End

Function tClamp16SetVarProcGraphExpand(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	ModifyGraph expand = varNum
End

Function tClamp16SetVarCheckCouplingADC(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	Variable num_channel	
	Switch(strlen(varName))
		case 16:	
			sscanf varName, "OscilloCmdPulse%f", num_channel
			SVAR CouplingADC = $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
			If(strlen(CouplingADC) != 1)
				Abort
			endif
			NVAR CouplingPulse = $("root:Packages:tClamp16:OscilloCmdPulse" + CouplingADC)
			break			
		case 14:
			sscanf varName, "SealTestPulse%f", num_channel
			SVAR CouplingADC = $("root:Packages:tClamp16:CouplingADC_ADC" + Num2str(num_channel))
			If(strlen(CouplingADC) != 1)
				Abort
			endif
			NVAR CouplingPulse = $("root:Packages:tClamp16:SealTestPulse" + CouplingADC)
			break
		default:
			Abort
			break
	endswitch

	CouplingPulse = varNum
End

Function tClamp16OSCLiveModeCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	Variable num_channel
	
	sscanf ctrlName, "ChecktClampOSCLiveMode%f", num_channel
	ModifyGraph live($("ScaledADC" + Num2str(num_channel))) = checked
End

Function tClamp16AscaleOSCADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampAscaleOSCADC%f", num_channel
	NVAR OscilloFreq = root:Packages:tClamp16:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Wave ScaledADC = $("root:Packages:tClamp16:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp16:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	SetAxis/A left
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom
	
	Wave DigitalOut = $("root:Packages:tClamp16:DigitalOut")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut
End

Function tClamp16FscaleOSCADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampFscaleOSCADC%f", num_channel
	NVAR OscilloFreq = root:Packages:tClamp16:OscilloFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Wave ScaledADC = $("root:Packages:tClamp16:ScaledADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
	Wave OscilloADC = $("root:Packages:tClamp16:OscilloADC" + Num2str(num_channel))
	SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom

	NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+ Num2str(num_channel))
	NVAR AmpGainADC = $("root:Packages:tClamp16:AmpGainADC" + Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" + Num2str(num_channel))
	NVAR ADCOffset = $("root:Packages:tClamp16:ADCOffset" + Num2str(num_channel))
	NVAR InputOffset =  $("root:Packages:tClamp16:InputOffset"+ Num2str(num_channel))
	
	Variable leftmax = (+1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	Variable leftmin = (-1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	SetAxis/A left leftmin, leftmax

	Wave DigitalOut = $("root:Packages:tClamp16:DigitalOut")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut
end

Function tClamp16RescaleAllOSCADC()
	String ctrlName
	
	NVAR OscilloFreq = root:Packages:tClamp16:OscilloFreq	
	Variable num_channel = 0
	
	do
		SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
		Wave ScaledADC = $("root:Packages:tClamp16:ScaledADC" + Num2str(num_channel))
		SetScale/P x 0, (1/OscilloFreq), "s", ScaledADC
		Wave OscilloADC = $("root:Packages:tClamp16:OscilloADC" + Num2str(num_channel))
		SetScale/P x 0, (1/OscilloFreq), "s", OscilloADC
		If(WinType("tClamp16OscilloADC" + Num2str(num_channel)) == 1)
			Label/W = $("tClamp16OscilloADC" + Num2str(num_channel)) left ("\\u"+UnitADC)
		endif
		num_channel += 1
	while(num_channel <=7)
	
	Wave DigitalOut = $("root:Packages:tClamp16:DigitalOut")
	SetScale/P x 0, (1/OscilloFreq), "s", DigitalOut
End

Function tClamp16CmdClear(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BtClearCmdPulse%f", num_channel
	NVAR OscilloCmdPulse = $("root:Packages:tClamp16:OscilloCmdPulse" + Num2str(num_channel))
	
	OscilloCmdPulse = 0
	
	tClamp16SetVarCheckCouplingADC("",OscilloCmdPulse,Num2str(OscilloCmdPulse),("OscilloCmdPulse" + Num2str(num_channel)))
End

Function tClamp16EditRecordingChecks(ctrlName) : ButtonControl
	String ctrlName
	NewPanel/N=EditRecordingCheckADCs/W=(368,91,633,144)
	CheckBox ChecktClampRecordingADC0_tab1,pos={14,9},size={24,14},title="0",variable= root:Packages:tClamp16:RecordingCheckADC0
	CheckBox ChecktClampRecordingADC1_tab1,pos={44,9},size={24,14},title="1",variable= root:Packages:tClamp16:RecordingCheckADC1
	CheckBox ChecktClampRecordingADC2_tab1,pos={74,9},size={24,14},title="2",variable= root:Packages:tClamp16:RecordingCheckADC2
	CheckBox ChecktClampRecordingADC3_tab1,pos={104,9},size={24,14},title="3",variable= root:Packages:tClamp16:RecordingCheckADC3
	CheckBox ChecktClampRecordingADC4_tab1,pos={134,9},size={24,14},title="4",variable= root:Packages:tClamp16:RecordingCheckADC4
	CheckBox ChecktClampRecordingADC5_tab1,pos={164,9},size={24,14},title="5",variable= root:Packages:tClamp16:RecordingCheckADC5
	CheckBox ChecktClampRecordingADC6_tab1,pos={194,9},size={24,14},title="6",variable= root:Packages:tClamp16:RecordingCheckADC6
	CheckBox ChecktClampRecordingADC7_tab1,pos={224,9},size={24,14},title="7",variable= root:Packages:tClamp16:RecordingCheckADC7
	Button BtKillTempEditPanelForRCAs,pos={102,27},size={50,20},proc=tClamp16KillTempPanelForRCAs,title="OK"
End

Function tClamp16KillTempPanelForRCAs(ctrlName) : ButtonControl
	String ctrlName
	
	KillWindow EditRecordingCheckADCs
	tClamp16BitUpdate("root:Packages:tClamp16:RecordingCheckADC", "root:Packages:tClamp16:RecordingBit", 8)
End

Function tClamp16CheckProcRecordingBit(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	tClamp16BitUpdate("root:Packages:tClamp16:RecordingCheckADC", "root:Packages:tClamp16:RecordingBit", 8)
End

Function tClamp16OSCShowHide(ctrlName) : ButtonControl
	String ctrlName

	String SFL
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp16OscilloADC*",";","WIN:1"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BtOSCShow_tab1" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BtOSCHide_tab1" :
				DoWindow/HIDE = 1 $SFL
				break
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Function tClamp16ApplyProtocolSetting()
	SVAR SelectedProtocol = root:Packages:tClamp16:SelectedProtocol
	SVAR StrITC16SeqDAC = root:Packages:tClamp16:StrITC16SeqDAC
	SVAR StrITC16SeqADC = root:Packages:tClamp16:StrITC16SeqADC
	
	NVAR RecordingCheckADC0 =  root:Packages:tClamp16:RecordingCheckADC0
	NVAR RecordingCheckADC1 =  root:Packages:tClamp16:RecordingCheckADC1
	NVAR RecordingCheckADC2 =  root:Packages:tClamp16:RecordingCheckADC2
	NVAR RecordingCheckADC3 =  root:Packages:tClamp16:RecordingCheckADC3
	NVAR RecordingCheckADC4 =  root:Packages:tClamp16:RecordingCheckADC4
	NVAR RecordingCheckADC5 =  root:Packages:tClamp16:RecordingCheckADC5
	NVAR RecordingCheckADC6 =  root:Packages:tClamp16:RecordingCheckADC6
	NVAR RecordingCheckADC7 =  root:Packages:tClamp16:RecordingCheckADC7

	NVAR OscilloCounterLimit =  root:Packages:tClamp16:OscilloCounterLimit
	NVAR OscilloSamplingNpnts =  root:Packages:tClamp16:OscilloSamplingNpnts
	NVAR OscilloITC16ExtTrig =  root:Packages:tClamp16:OscilloITC16ExtTrig
	NVAR OscilloITC16Output =  root:Packages:tClamp16:OscilloITC16Output
	NVAR OscilloITC16Overflow =  root:Packages:tClamp16:OscilloITC16Overflow
	NVAR OscilloITC16Reserved =  root:Packages:tClamp16:OscilloITC16Reserved
	NVAR OscilloITC16IPeriod =  root:Packages:tClamp16:OscilloITC16Period
	
	String/G StrAcquisitionProcName = SelectedProtocol		//any name of acquisition macro
	Variable/G RecordingBit = tClamp16BitCoder(RecordingCheckADC0, RecordingCheckADC1, RecordingCheckADC2, RecordingCheckADC3, RecordingCheckADC4, RecordingCheckADC5, RecordingCheckADC6, RecordingCheckADC7) 		
	Variable/G OscilloITC16Flags = tClamp16BitCoder(OscilloITC16ExtTrig, OscilloITC16Output, OscilloITC16Overflow, OscilloITC16Reserved, 0, 0, 0, 0)
	Variable/G OscilloITC16StrlenSeq = Strlen(StrITC16SeqDAC)
	
	Wave OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut, FIFOOut, FIFOin
	Redimension/N = (OscilloSamplingNpnts) OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut
	Redimension/N = (OscilloSamplingNpnts*OscilloITC16StrlenSeq) FIFOOut, FIFOin
	
	tClamp16UpDateOSCFreqAndAcqTime()
end

Function tClamp16ProtocolRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp16:TimerISI
	NVAR npnts = root:Packages:tClamp16:OscilloSamplingNpnts
	tClamp16OscilloRedimension(ctrlName,npnts,"","")
	
	SetBackground  tClamp16ProtocolBGFlowControl()
	If(StringMatch(ctrlName, "BttClampProtocolRun_tab1"))
		tClamp16TimerReset("")
	endif
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
End

Function tClamp16ProtocolBGFlowControl()
	NVAR ISI = root:Packages:tClamp16:OscilloISI
	NVAR Counter = root:Packages:tClamp16:OscilloCounter
	NVAR CounterLimit = root:Packages:tClamp16:OscilloCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp16:TimerISITicks
	NVAR NumTrial = root:Packages:tClamp16:NumTrial
	SVAR SelectedProtocol = root:Packages:tClamp16:SelectedProtocol
	
	Variable now = ticks

	If(ISI <= (now - TimerISITicks)|| Counter ==0)
		TimerISITicks = now

		Execute/Q SelectedProtocol
		tClamp16OSCInterleave()
		Execute/Q "tClamp16OSCStimAndSample()"
		
		tClamp16ScaledADCDuplicate()
		Counter += 1
	endIf

	tClamp16TimerUpdate()
	
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	else
		NumTrial += 1
		return 1
	endif
End

Function tClamp16OSCInterleave()
	NVAR StrlenSeq = root:Packages:tClamp16:OscilloITC16StrlenSeq
	SVAR SeqDAC = root:Packages:tClamp16:StrITC16SeqDAC

	Wave FIFOout = $"root:Packages:tClamp16:FIFOout"
	
	Variable num_DAC = 0, i = 0, j = 0
	
	do
		StrSwitch (SeqDAC[i])
			case "D":
				Wave DigitalOut = $"root:Packages:tClamp16:DigitalOut"
				FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=DigitalOut[p/StrlenSeq]
				break
			default:
				Variable num_ADC 
				For(j = 0; j < 8; j += 1)
					SVAR CouplingDAC_ADC = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(j))
					If(Stringmatch(CouplingDAC_ADC, SeqDAC[i]))
						num_ADC = j
						Wave OscilloADC = $("root:Packages:tClamp16:OscilloADC" + Num2str(num_ADC))
						FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=OscilloADC[p/StrlenSeq]
//						break
					endif
				endfor
				break
		endSwitch
		i += 1
	while(i < StrlenSeq)
end

Proc tClamp16OSCStimAndSample()
	silent 1	// retrieving data...

	//Global Strings
	String SeqDAC = "root:Packages:tClamp16:StrITC16SeqDAC"
	String SeqADC = "root:Packages:tClamp16:StrITC16SeqADC"
	//Global Variables
	String Period = "root:Packages:tClamp16:OscilloITC16Period"
	String Flags = "root:Packages:tClamp16:OscilloITC16Flags"
	//Global Waves	
	String FIFOout = "root:Packages:tClamp16:FIFOout"
	String FIFOin = "root:Packages:tClamp16:FIFOin"

	Variable InitDAC0 = tClamp16InitDAC("0")
	Variable InitDAC1 = tClamp16InitDAC("1")
	Variable InitDAC2 = tClamp16InitDAC("2")
	Variable InitDAC3 = tClamp16InitDAC("3")

	ITC16SetAll InitDAC0,InitDAC1,InitDAC2,InitDAC3,0,0		// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC16seq $SeqDAC, $SeqADC

	PauseUpdate

	ITC16StimandSample $FIFOout, $FIFOin, $Period, $Flags, 0
	tClamp16OSCScalingDeinterleave()
    
      ResumeUpdate
EndMacro

Function tClamp16InitDAC(instr)
	String instr
	
	SVAR  SeqADC = root:Packages:tClamp16:StrITC16SeqADC
	Wave FIFOout = $"root:Packages:tClamp16:FIFOout"
	Variable SeqPos = StrSearch(SeqADC, instr, 0)
	
	If(SeqPos == -1)
		return 0
	else
		return FIFOout[SeqPos]/3200
	endIf	
end

Function tClamp16OSCScalingDeinterleave()
	Variable Offset = 0
	Variable i = 0
	Variable num_channel = 0
	
	SVAR SeqADC = root:Packages:tClamp16:StrITC16SeqADC
	NVAR StrlenSeq = root:Packages:tClamp16:OscilloITC16StrlenSeq
	
	Wave FIFOin = $"root:Packages:tClamp16:FIFOin"
	
	do
		StrSwitch (SeqADC[i])
			case "D":
				break
			case "N":
				break
			default:
				sscanf SeqADC[i], "%d", num_channel
				NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+ Num2str(num_channel))
				NVAR AmpGainADC = $("root:Packages:tClamp16:AmpGainADC" + Num2str(num_channel))
				NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" + Num2str(num_channel))
				NVAR ADCOffset = $("root:Packages:tClamp16:ADCOffset" + Num2str(num_channel))
				NVAR InputOffset =  $("root:Packages:tClamp16:InputOffset"+ Num2str(num_channel))
				NVAR ADCValueVolt = $("root:Packages:tClamp16:ADCValueVolt" + Num2str(num_channel))
				NVAR ADCValuePoint = $("root:Packages:tClamp16:ADCValuePoint" + Num2str(num_channel))
		
				Wave ScaledADC = $("root:Packages:tClamp16:ScaledADC" +  Num2str(num_channel))
	
				ScaledADC[0, ] = (FIFOin[StrlenSeq * p + i] *(ADCRange/10)/3200 + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
		
				ADCValueVolt = FIFOin[i]/3200
				ADCValuePoint = FIFOin[i]
				break
		endSwitch
		i += 1
	while(i < StrlenSeq)
End

Function tClamp16ScaledADCDuplicate()
	NVAR NumTrial = root:Packages:tClamp16:NumTrial
	NVAR Counter = root:Packages:tClamp16:OscilloCounter
	
	Variable num_channel = 0
	
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16
	
	do
		NVAR RecordingCheckADC = $("root:Packages:tClamp16:RecordingCheckADC" + Num2str(num_channel))
		If(RecordingCheckADC)
			Duplicate/O $("ScaledADC"+Num2str(num_channel)), $("Temp_"+Num2str(NumTrial) + "_"+ Num2str(num_channel) + "_" + Num2str(Counter))
			If(WinType("tClamp16OscilloADC" + Num2str(num_channel)) == 0)
				tClamp16NewOscilloADC(num_channel)
			endif
			AppendToGraph/W=$("tClamp16OscilloADC" + Num2str(num_channel)) $("Temp_"+Num2str(NumTrial) + "_"+ Num2str(num_channel) + "_" + Num2str(Counter))
			RemoveFromGraph/W=$("tClamp16OscilloADC" + Num2str(num_channel)) $("ScaledADC" + Num2str(num_channel))
			AppendToGraph/W=$("tClamp16OscilloADC" + Num2str(num_channel))	$("ScaledADC" + Num2str(num_channel))
			ModifyGraph/W=$("tClamp16OscilloADC" + Num2str(num_channel)) rgb($("ScaledADC" + Num2str(num_channel))) = (0,0,0)
		endIf
		num_channel += 1
	While(num_channel < 8)
	
	SetDataFolder fldrSav0	
end

Function tClamp16ProtocolSave(ctrlName) : ButtonControl
	String ctrlName
	
	tClamp16_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16

	String SFL = ""
	String SFLWave = ""
	Variable i = 0, num_channel = 0
	String WaveListTemp = ""
	
	i = 0
	do
		For(num_channel = 0; num_channel < 8; num_channel += 1)
			WaveListTemp += WaveList("Temp_" + Num2str(i) + "_" + Num2str(num_channel) + "_*", ";", "")
		endFor
		If(Strlen(WaveListTemp) == Strlen(WaveList("Temp_*_*_*", ";", "")))
			break
		endif
		i += 1
	while(1)
	
	i = 0
	do
		SFL = StringFromList(i, WaveListTemp)
		if(Strlen(SFL) == 0)
			break
		endif
		SFLWave = ReplaceString("Temp", SFL, "w")
		Duplicate/O $SFL, root:$SFLWave
		i += 1		
	while(1)

	SetDataFolder fldrSav0
End

Function tClamp16ClearTempWaves(ctrlName) : ButtonControl
	String ctrlName

	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16
	
	String SFL = ""
	String SFLWave = ""
	Variable i = 0, j = 0, k = 0,  num_channel = 0
	
	do
		SFL = StringFromList(i, WaveList("Temp*", ";", ""))
		if(strlen(SFL) == 0)
			break
		endif
		sscanf SFL, "Temp_%f_%f_%f", j, num_channel, k
		If(WinType("tClamp16OscilloADC" + Num2str(num_channel)) == 1)
			RemoveFromGraph/Z/W=$("tClamp16OscilloADC" + Num2str(num_channel)) $SFL
		endif
		KillWaves $SFL
	while(1)
	
	SetDataFolder fldrSav0
End

Function tClamp16EditProtocol(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR SelectedProtocol = root:Packages:tClamp16:SelectedProtocol
	Variable StrlenSrcProc = strlen(SelectedProtocol)
	DisplayProcedure/W= $(SelectedProtocol[0, StrlenSrcProc - 3]+".ipf") SelectedProtocol[0, StrlenSrcProc - 3]
End

Function tClamp16ResetNumTrial(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR NumTrial = root:Packages:tClamp16:NumTrial
	
	NumTrial = 0
End

Function tClamp16EditITC16Seq(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR StrITC16SeqDAC = root:Packages:tClamp16:StrITC16SeqDAC
	SVAR StrITC16SeqADC = root:Packages:tClamp16:StrITC16SeqADC
	NVAR OscilloITC16StrlenSeq = root:Packages:tClamp16:OscilloITC16StrlenSeq
	
	String DAC, ADC
	
	Prompt DAC "DACSeq"
	Prompt ADC "ADCSeq"
	DoPrompt "DAC and ADC must be in same length.", DAC, ADC
	If(V_flag)
		Abort
	endif
	
	If(Strlen(DAC) != Strlen(ADC))
		DoAlert 0, "Different length! DAC and ADC must be in same length."
		Abort
	endIf
	
	StrITC16SeqDAC = DAC
	StrITC16SeqADC = ADC
	OscilloITC16StrlenSeq = Strlen(StrITC16SeqDAC)
	
	tClamp16UpDateOSCFreqAndAcqTime()
End

Function tClamp16SetVarProcOscilloFreq(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	tClamp16UpDateOSCFreqAndAcqTime()
End

Function tClamp16UpDateOSCFreqAndAcqTime()
	NVAR OscilloITC16StrlenSeq = root:Packages:tClamp16:OscilloITC16StrlenSeq
	NVAR OscilloITC16Period = root:Packages:tClamp16:OscilloITC16Period
	NVAR OscilloFreq = root:Packages:tClamp16:OscilloFreq
	NVAR OscilloSamplingNpnts = root:Packages:tClamp16:OscilloSamplingNpnts
	NVAR OscilloAcqTime = root:Packages:tClamp16:OscilloAcqTime
	
	OscilloFreq = 1/(1E-06*OscilloITC16Period*OscilloITC16StrlenSeq)
	OscilloAcqTime = OscilloSamplingNpnts/OscilloFreq
	
	If(OscilloITC16StrlenSeq * OscilloFreq > 200001)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp16RescaleAllOSCADC()
end

Function tClamp16OscilloRedimension(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName

	NVAR OscilloITC16StrlenSeq = root:Packages:tClamp16:OscilloITC16StrlenSeq

	tClamp16_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16

	Wave FIFOout, FIFOin, OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut
	Redimension/N = (varNum) OscilloADC0, OscilloADC1, OscilloADC2, OscilloADC3, OscilloADC4, OscilloADC5, OscilloADC6, OscilloADC7, ScaledADC0, ScaledADC1, ScaledADC2, ScaledADC3, ScaledADC4, ScaledADC5, ScaledADC6, ScaledADC7, DigitalOut
	Redimension/N = (varNum*OscilloITC16StrlenSeq) FIFOout, FIFOin
	
	tClamp16UpDateOSCFreqAndAcqTime()

	SetDataFolder fldrSav0
End

Function tClamp16CheckProcITC16Flags(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR OscilloITC16Flags = root:Packages:tClamp16:OscilloITC16Flags
	NVAR OscilloITC16ExtTrig = root:Packages:tClamp16:OscilloITC16ExtTrig
	NVAR OscilloITC16Output = root:Packages:tClamp16:OscilloITC16Output
	NVAR OscilloITC16Overflow = root:Packages:tClamp16:OscilloITC16Overflow
	NVAR OscilloITC16Reserved = root:Packages:tClamp16:OscilloITC16Reserved
	
	OscilloITC16Flags = tClamp16BitCoder(OscilloITC16ExtTrig, OscilloITC16Output, OscilloITC16Overflow, OscilloITC16Reserved, 0, 0, 0, 0)
End

//End Oscillo
////////////////////////////////////////////////////////////////////////////
//SealTest

Function tClamp16SealTestBGRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp16:TimerISI
	NVAR npnts = root:Packages:tClamp16:SealSamplingNpnts
	
	tClamp16SealRedimension(ctrlName,npnts,"","")
	SetBackground  tClamp16SealTestBGFlowControl()
	tClamp16TimerReset("")
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
end

Function tClamp16SealTestBGFlowControl()
	NVAR ISI = root:Packages:tClamp16:SealTestISI
	NVAR Counter = root:Packages:tClamp16:SealTestCounter
	NVAR CounterLimit = root:Packages:tClamp16:SealTestCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp16:TimerISITicks

	Variable now = ticks

	If(ISI <= (now - TimerISITicks))
		TimerISITicks = now
		tClamp16SealInterleave()
		Execute/Q "tClamp16SealStimAndSample()"
		tClamp16PipetteUpdate()
		Counter += 1
	endIf

	tClamp16TimerUpdate()
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	endif
end

Function tClamp16SealInterleave()
	NVAR TrigOut = root:Packages:tClamp16:SealITC16TrigOut
	NVAR StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq
	NVAR npnts = root:Packages:tClamp16:SealSamplingNpnts
	SVAR SeqADC = root:Packages:tClamp16:SealITC16SeqADC
	
	Wave DigitalOutSeal = $"root:Packages:tClamp16:DigitalOutSeal"	
	Wave FIFOout = $"root:Packages:tClamp16:FIFOout"
	
	Variable num_channel = 0, i = 0
	
	If(Trigout)
		If(StrlenSeq != 1)
			do
				sscanf SeqADC[i], "%d", num_channel
				Wave SealTestPntsADC = $("root:Packages:tClamp16:SealTestPntsADC" + Num2str(num_channel))
				NVAR TestPulse = $("root:Packages:tClamp16:SealTestPulse" + Num2str(num_channel))
				SealTestPntsADC = 0
				SealTestPntsADC[trunc(npnts*0.2), trunc(npnts*0.8)] = TestPulse
				SealTestPntsADC *= 3200
				FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=SealTestPntsADC[p/StrlenSeq]
				i += 1
			while(i < StrlenSeq)
		endif
		DigitalOutSeal[0, 2] = 1
		DigitalOutSeal[3, ] = 0
		FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=DigitalOutSeal[p/StrlenSeq]
	else
		do
			sscanf SeqADC[i], "%d", num_channel
			Wave SealTestPntsADC = $("root:Packages:tClamp16:SealTestPntsADC" + Num2str(num_channel))
			NVAR TestPulse = $("root:Packages:tClamp16:SealTestPulse" + Num2str(num_channel))
			SealTestPntsADC = 0
			SealTestPntsADC[trunc(npnts*0.2), trunc(npnts*0.8)] = TestPulse
			SealTestPntsADC *= 3200
			FIFOout[i,numpnts(FIFOout)-(StrlenSeq-i);StrlenSeq]=SealTestPntsADC[p/StrlenSeq]
			i += 1
		while(i < StrlenSeq)
	endif
end

Proc tClamp16SealStimAndSample()
	silent 1	// retrieving data...
	
	//Global Strings
	String SeqDAC = "root:Packages:tClamp16:SealITC16SeqDAC"
	String SeqADC = "root:Packages:tClamp16:SealITC16SeqADC"
	//Global Variables
	String Period = "root:Packages:tClamp16:SealITC16Period"
	String Flags = "root:Packages:tClamp16:SealITC16Flags"
	//Global Waves
	String FIFOout = "root:Packages:tClamp16:FIFOout"			//Out and In FIFO channel
	String FIFOin = "root:Packages:tClamp16:FIFOin"
	
	//body of macro
		
	ITC16SetAll 0,0,0,0,0,0					// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC16seq $SeqDAC, $SeqADC

	PauseUpdate

	ITC16StimandSample $FIFOout, $FIFOin, $Period, $Flags, 0
	tClamp16SealScalingDeinterleave()
   
      ResumeUpdate
endMacro

Function tClamp16SealScalingDeinterleave()
	SVAR SeqADC = root:Packages:tClamp16:SealITC16SeqADC
	NVAR StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq
	
	Variable i = 0, num_channel = 0
	
	Wave FIFOin = $"root:Packages:tClamp16:FIFOin"
	
	do
		sscanf SeqADC[i], "%d", num_channel
			NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+ Num2str(num_channel))
			NVAR AmpGainADC = $("root:Packages:tClamp16:AmpGainADC" + Num2str(num_channel))
			NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" + Num2str(num_channel))
			NVAR ADCOffset = $("root:Packages:tClamp16:ADCOffset" + Num2str(num_channel))
			NVAR InputOffset =  $("root:Packages:tClamp16:InputOffset"+ Num2str(num_channel))
			NVAR ADCValueVolt = $("root:Packages:tClamp16:ADCValueVolt" + Num2str(num_channel))
			NVAR ADCValuePoint = $("root:Packages:tClamp16:ADCValuePoint" + Num2str(num_channel))
	
			Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" +  Num2str(num_channel))
	
			SealTestADC[0, ] = (FIFOin[StrlenSeq * p + i] *(ADCRange/10)/3200 + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
		
			ADCValueVolt = FIFOin[i]/3200
			ADCValuePoint = FIFOin[i]
		i += 1
	while(i < StrlenSeq)
End

Function tClamp16PipetteUpdate()
	NVAR AcqTime = root:Packages:tClamp16:SealAcqTime
	
	Variable i = 0
	
	For(i=0;i<8;i+=1)
		NVAR bit = $("root:Packages:tClamp16:SealTestCheckADC" + Num2str(i))
		If(bit)
			NVAR ADCMode = $("root:Packages:tClamp16:ADCMode" + Num2str(i))
			NVAR SealTestPulse = $("root:Packages:tClamp16:SealTestPulse" + Num2str(i))
			NVAR PipetteR = $("root:Packages:tClamp16:PipetteR" + Num2str(i))
			SVAR CouplingDAC_ADC = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(i))
	
			Variable CommandSens = tClamp16CommandSensReturn(CouplingDAC_ADC, ADCMode)
					
			PipetteR = tClamp16PipetteR(i, ADCmode, SealTestPulse, CommandSens, AcqTime)
		endif
	endfor
end

Function tClamp16CommandSensReturn(CouplingDAC_ADC, ADCMode)
	String CouplingDAC_ADC
	Variable ADCMode

	NVAR VC_DAC0 = root:Packages:tClamp16:CommandSensVC_DAC0	
	NVAR CC_DAC0 = root:Packages:tClamp16:CommandSensCC_DAC0
	NVAR VC_DAC1 = root:Packages:tClamp16:CommandSensVC_DAC1
	NVAR CC_DAC1 = root:Packages:tClamp16:CommandSensCC_DAC1
	NVAR VC_DAC2 = root:Packages:tClamp16:CommandSensVC_DAC2
	NVAR CC_DAC2 = root:Packages:tClamp16:CommandSensCC_DAC2
	NVAR VC_DAC3 = root:Packages:tClamp16:CommandSensVC_DAC3
	NVAR CC_DAC3 = root:Packages:tClamp16:CommandSensCC_DAC3
	
	StrSwitch (CouplingDAC_ADC)
		case "0":
			If(ADCMode)
				return CC_DAC0
			else
				return VC_DAC0
			endif
			break
		case "1":
			If(ADCMode)
				return CC_DAC1
			else
				return VC_DAC1
			endif
			break
		case "2":
			If(ADCMode)
				return CC_DAC2
			else
				return VC_DAC2
			endif
			break
		case "3":
			If(ADCMode)
				return CC_DAC3
			else
				return VC_DAC3
			endif
			break		
		default:
			return NaN
			break
	endSwitch
end

Function tClamp16PipetteR(num_channel, mode, SealTestPulse, CommandSens, AcqTime)
	Variable num_channel, mode, SealTestPulse, CommandSens, AcqTime
	
	Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" + Num2str(num_channel))
	
	If(mode)
		return 1e-06*(mean(SealTestADC, 0.7*AcqTime, 0.75*AcqTime) - mean(SealTestADC, 0.1*AcqTime, 0.15*AcqTime))/(SealTestPulse*CommandSens*1e-12)
	else
		return 1e-06*(SealTestPulse*CommandSens*1e-03)/(mean(SealTestADC, 0.7*AcqTime, 0.75*AcqTime) - mean(SealTestADC, 0.1*AcqTime, 0.15*AcqTime))
	endif
end

Function tClamp16MainSealShowHide(ctrlName) : ButtonControl
	String ctrlName
	
	String SFL =""
	Variable i = 0

	do
		SFL = StringFromList(i, WinList("tClamp16SealTestADC*",";","WIN:1"))
		if(strlen(SFL) == 0)
			break
		endif
		StrSwitch(ctrlName)
			case "BttClampMainSealTestShow_tab2" :
				DoWindow/HIDE = 1 $SFL
				DoWindow/HIDE = 0 $SFL
				DoWindow/F $SFL
				break
			case "BttClampMainSealTestHide_tab2" :
				DoWindow/HIDE = 1 $SFL
				break
			default :
				break
		endSwitch
		i += 1
	while(1)
End

Function tClamp16MainSealTestCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	Variable num_channel
	
	sscanf ctrlName, "ChecktClampMainSealADC%f", num_channel
	If(checked)
		If(WinType("tClamp16SealTestADC"+Num2str(num_channel)) == 1)
			DoWindow/HIDE = ? $("tClamp16SealTestADC"+Num2str(num_channel))
			If(V_flag == 1)
				DoWindow/HIDE = 1 $("tClamp16SealTestADC"+Num2str(num_channel))
			else
				DoWindow/HIDE = 0/F $("tClamp16SealTestADC"+Num2str(num_channel))
			endif
		else	
			tClamp16NewSealTestADC(num_channel)
		endif
	else
		DoWindow/HIDE = 1 $("tClamp16SealTestADC"+Num2str(num_channel))
	endif
	
	tClamp16BitUpdate("root:Packages:tClamp16:SealTestCheckADC", "root:Packages:tClamp16:SealTestBit", 8)
	tClamp16SealStrSeqUpdate()
End

Function tClamp16SealStrSeqUpdate()
	NVAR Trig = root:Packages:tClamp16:SealITC16Trigout
	NVAR SealITC16StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq

	SVAR SeqDAC = root:Packages:tClamp16:SealITC16SeqDAC
	SVAR SeqADC = root:Packages:tClamp16:SealITC16SeqADC
	
	SeqDAC = ""
	SeqADC = ""
	
	Variable i = 0
	For(i = 0; i < 8; i += 1)
		NVAR bit = $("root:Packages:tClamp16:SealTestCheckADC" + Num2str(i))
		SVAR CouplingDAC = $("root:Packages:tClamp16:CouplingDAC_ADC" + Num2str(i))
		bit = trunc(bit)
		If(bit)
			If(StringMatch(CouplingDAC, "none"))
				SeqDAC += "N"
			else
				SeqDAC += CouplingDAC
			endif
			SeqADC += Num2str(i)
		endif
	endFor
		
	Trig = trunc(Trig)
	If(Trig)
		SeqDAC += "D"
		SeqADC += "N"
	endif	
	
	SealITC16StrlenSeq = Strlen(SeqDAC)
	tClamp16UpDateSealFreqAcqTime()
end

Function tClamp16CheckSealTrigOut(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	tClamp16SealStrSeqUpdate()
End

Function tClamp16NewSealTestADC(num_channel)
	Variable num_channel

	NVAR SealTestFreq = root:Packages:tClamp16:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	Display/W=(99+27*num_channel,293-20*num_channel,375.75+27*num_channel,531.5-20*num_channel)/N=$("tClamp16SealTestADC"+Num2str(num_channel)) SealTestADC
	ModifyGraph live ($("SealTestADC" + Num2str(num_channel))) = 1
	Label left ("\\u"+UnitADC)
	ControlBar 40
	Button BtYPlus,pos={44, 0},size={20,20},proc=tClamp16GraphScale,title="+"
	Button BtYMinus,pos={44,19},size={20,20},proc=tClamp16GraphScale,title="-"
	Button BtXMinus,pos={1, 1},size={20,20},proc=tClamp16GraphScale,title="-"
	Button BtXPlus,pos={20, 1},size={20,20},proc=tClamp16GraphScale,title="+"
	SetVariable $("SetvarExpandSealGraph" + Num2str(num_channel)),pos={3,21},size={38,16},proc=tClamp16SetVarProcGraphExpand,title=" ",limits={0.5,8,0.5},value= $("root:Packages:tClamp16:SealExpand" + Num2str(num_channel))
	Button $("BttClampAutoscaleSealADC" +Num2str(num_channel)),pos={72,0},size={35,20},proc=tClamp16AscaleSealADC,title="Auto"
	Button $("BttClampFullscaleSealADC" +Num2str(num_channel)),pos={72,19},size={35,20},proc=tClamp16FscaleSealADC,title="Full"
	Button $("BttClampRunSealADC"+ Num2str(num_channel)),pos={112,0},size={35,20},proc=tClamp16SealTestBGRun,title="Run"
	Button $("BttClampAbortSealADC"+ Num2str(num_channel)),pos={112,19},size={35,20},proc=tClamp16BackGStop,title="Stop"
	Button $("BtClearTestPulse" + Num2str(num_channel)),pos={151,0},size={50,20},proc=tClamp16SealTestClear,title="DAC (V)",fColor=(32768,40704,65280)
	SetVariable $("SetvarSetSealTestPulse" + Num2str(num_channel)),pos={204,3},proc=tClamp16SetVarCheckCouplingADC,size={50,16},title=" ",limits={-10,10,0.01},value= $("root:Packages:tClamp16:SealTestPulse" + Num2str(num_channel))
	ValDisplay $("ValdispPipetteR" + Num2str(num_channel)),pos={152,20},size={100,19},title="Mƒ¶",fSize=18,limits={0,0,0},barmisc={0,1000},frame=5,value= #("root:Packages:tClamp16:PipetteR" + Num2str(num_channel))
	CheckBox $("ChecktClampSealLiveMode"+Num2str(num_channel)),pos={292,14},size={70,14},proc=tClamp16SealLiveModeCheckProc,title="Live mode",value= 1
	SetDrawLayer UserFront
End

Function tClamp16AscaleSealADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampAutoscaleSealADC%f", num_channel
	NVAR SealTestFreq = root:Packages:tClamp16:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	SetAxis/A left
	Label left ("\\u"+UnitADC)
	SetAxis/A bottom
End

Function tClamp16FscaleSealADC(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BttClampFullscaleSealADC%f", num_channel
	NVAR SealTestFreq = root:Packages:tClamp16:SealTestFreq
	SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
	Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" + Num2str(num_channel))
	SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
	SetAxis/A bottom
	Label left ("\\u"+UnitADC)
	
	NVAR ADCRange = $("root:Packages:tClamp16:ADCRange"+ Num2str(num_channel))
	NVAR AmpGainADC = $("root:Packages:tClamp16:AmpGainADC" + Num2str(num_channel))
	NVAR ScalingFactorADC = $("root:Packages:tClamp16:ScalingFactorADC" + Num2str(num_channel))
	NVAR ADCOffset = $("root:Packages:tClamp16:ADCOffset" + Num2str(num_channel))
	NVAR InputOffset =  $("root:Packages:tClamp16:InputOffset"+ Num2str(num_channel))
	
	Variable leftmax = (+1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	Variable leftmin = (-1.024*ADCRange + ADCOffset*AmpGainADC + InputOffset) /(AmpGainADC*ScalingFactorADC)
	SetAxis/A left leftmin, leftmax
end

Function tClamp16RescaleAllSealADC()
	NVAR SealTestFreq = root:Packages:tClamp16:SealTestFreq	
	Variable num_channel = 0
	
	do
		SVAR UnitADC = $("root:Packages:tClamp16:UnitADC" + Num2str(num_channel))
		Wave SealTestADC = $("root:Packages:tClamp16:SealTestADC" + Num2str(num_channel))
		SetScale/P x 0, (1/SealTestFreq), "s", SealTestADC
		If(WinType("tClamp16SealTestADC" + Num2str(num_channel)) == 1)
			Label/W = $("tClamp16SealTestADC" + Num2str(num_channel)) left ("\\u"+UnitADC)
		endif
		num_channel += 1
	while(num_channel <=7 )
End

Function tClamp16SealTestClear(ctrlName) : ButtonControl
	String ctrlName
	
	Variable num_channel
	sscanf ctrlName, "BtClearTestPulse%f", num_channel
	
	NVAR SealTestPulse = $("root:Packages:tClamp16:SealTestPulse" + Num2str(num_channel))
	
	If(SealTestPulse)
		SealTestPulse = 0
	else
		SealTestPulse = 0.25
	endif
	
	tClamp16SetVarCheckCouplingADC("",SealTestPulse,Num2str(SealTestPulse),("SealTestPulse" + Num2str(num_channel)))
End

Function tClamp16GraphScale(ctrlName) : ButtonControl
	String ctrlName
	
	Variable AX, AY, RX, RY
	
	GetAxis/Q bottom
	AX = V_min
	RX = V_max - V_min
	GetAxis/Q left
	AY = V_min
	RY = V_max - V_min

	StrSwitch (ctrlName)
		case "BtYPlus":
			SetAxis left (AY + 0.05 * RY), (AY + 0.95 * RY)
			break
		case "BtYMinus":
			SetAxis left (AY - 0.05 * RY), (AY + 1.05 * RY)
			break
		case "BtXPlus":
			SetAxis bottom (AX + 0.05 * RX), (AX + 0.95 * RX)
			break
		case "BtXMinus":
			SetAxis bottom (AX - 0.05 * RX), (AX + 1.05 * RX)
			break
		default:
			break
	endSwitch
End

Function tClamp16SealFreqPopMenuProc(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	NVAR SealTestFreq = root:Packages:tClamp16:SealTestFreq
	SealTestFreq = Str2Num(popStr) * 1000	
End

Function tClamp16SealLiveModeCheckProc(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	
	Variable num_channel
	sscanf ctrlName, "ChecktClampSealLiveMode%f", num_channel
	ModifyGraph live ($("SealTestADC" + Num2str(num_channel))) = checked
End

Function tClamp16CheckSealITC16Flags(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked

	NVAR SealITC16Flags = root:Packages:tClamp16:SealITC16Flags
	NVAR SealITC16ExtTrig = root:Packages:tClamp16:SealITC16ExtTrig
	NVAR SealITC16Output = root:Packages:tClamp16:SealITC16Output
	NVAR SealITC16Overflow = root:Packages:tClamp16:SealITC16Overflow
	NVAR SealITC16Reserved = root:Packages:tClamp16:SealITC16Reserved
	
	SealITC16Flags = tClamp16BitCoder(SealITC16ExtTrig, SealITC16Output, SealITC16Overflow, SealITC16Reserved, 0, 0, 0, 0)
End

Function tClamp16EditSealITC16Seq(ctrlName) : ButtonControl
	String ctrlName
	
	SVAR SealITC16SeqDAC = root:Packages:tClamp16:SealITC16SeqDAC
	SVAR SealITC16SeqADC = root:Packages:tClamp16:SealITC16SeqADC
	NVAR SealITC16StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq
	
	String DAC, ADC
	
	Prompt DAC "DACSeq"
	Prompt ADC "ADCSeq"
	DoPrompt "DAC and ADC must be in same length.", DAC, ADC
	If(V_flag)
		Abort
	endif
	
	If(Strlen(DAC) != Strlen(ADC))
		DoAlert 0, "Different length! DAC and ADC must be in same length."
		Abort
	endIf
	
	SealITC16SeqDAC = DAC
	SealITC16SeqADC = ADC
	SealITC16StrlenSeq = Strlen(SealITC16SeqDAC)
	
	tClamp16UpDateSealFreqAcqTime()
End

Function tClamp16SetVarProcSealFreq(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	tClamp16UpDateSealFreqAcqTime()
End

Function tClamp16UpDateSealFreqAcqTime()
	NVAR SealITC16StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq
	NVAR SealITC16Period = root:Packages:tClamp16:SealITC16Period
	NVAR SealFreq = root:Packages:tClamp16:SealTestFreq
	NVAR SealSamplingNpnts = root:Packages:tClamp16:SealSamplingNpnts
	NVAR SealAcqTime = root:Packages:tClamp16:SealAcqTime
	
	SealFreq = 1/(1E-06*SealITC16Period*SealITC16StrlenSeq)
	SealAcqTime = SealSamplingNpnts/SealFreq
	
	If(SealITC16StrlenSeq * SealFreq > 200001)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp16RescaleAllSealADC()
end

Function tClamp16SealRedimension(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	NVAR SealITC16StrlenSeq = root:Packages:tClamp16:SealITC16StrlenSeq

	tClamp16_FolderCheck()
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Packages:tClamp16

	Wave FIFOout, FIFOin, SealTestPntsADC0, SealTestPntsADC1, SealTestPntsADC2, SealTestPntsADC3, SealTestPntsADC4, SealTestPntsADC5, SealTestPntsADC6, SealTestPntsADC7, SealTestADC0, SealTestADC1, SealTestADC2, SealTestADC3, SealTestADC4, SealTestADC5, SealTestADC6, SealTestADC7, DigitalOutSeal
	Redimension/N = (varNum) SealTestPntsADC0, SealTestPntsADC1, SealTestPntsADC2, SealTestPntsADC3, SealTestPntsADC4, SealTestPntsADC5, SealTestPntsADC6, SealTestPntsADC7, SealTestADC0, SealTestADC1, SealTestADC2, SealTestADC3, SealTestADC4, SealTestADC5, SealTestADC6, SealTestADC7, DigitalOutSeal
	Redimension/N = (varNum*SealITC16StrlenSeq) FIFOout, FIFOin
	
	tClamp16UpDateSealFreqAcqTime()

	SetDataFolder fldrSav0
End

//Seal Test End

///////////////////////////////////////////////////////////////////
// Stimulator

Function tClamp16PopMenuProcStimulator(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr

End

Function tClamp16SetVarProcStimulator(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	
	If(StringMatch(ctrlName, "SetvarStimulatorAcqTime_tab3"))
		tClamp16StimulatorTimeChanged()
	else
		tClamp16ApplyStimulatorSetting()
	endif
End

Function tClamp16StimulatorTimeChanged()
	NVAR Freq = root:Packages:tClamp16:StimulatorFreq
	NVAR SamplingNpnts =  root:Packages:tClamp16:StimulatorSamplingNpnts
	NVAR AcqTime = root:Packages:tClamp16:StimulatorAcqTime
	
	SamplingNpnts = AcqTime*Freq
	
	Wave DigitalOut = $"root:Packages:tClamp16:DigitalOut"
	Wave FIFOOut = $"root:Packages:tClamp16:FIFOOut"
	Wave FIFOIn = $"root:Packages:tClamp16:FIFOIn"
	
	Redimension/N = (SamplingNpnts) DigitalOut, FIFOOut, FIFOIn
End

Function tClamp16ApplyStimulatorSetting()
	NVAR StimulatorSamplingNpnts =  root:Packages:tClamp16:StimulatorSamplingNpnts
	Wave DigitalOut = $"root:Packages:tClamp16:DigitalOut"
	Wave FIFOOut = $"root:Packages:tClamp16:FIFOOut"
	Wave FIFOIn = $"root:Packages:tClamp16:FIFOIn"
	
	Redimension/N = (StimulatorSamplingNpnts) DigitalOut, FIFOOut, FIFOIn
	
	tClamp16UpDateStFreqAndAcqTime()
end

Function tClamp16UpDateStFreqAndAcqTime()
	NVAR StimulatorITC16Period = root:Packages:tClamp16:StimulatorITC16Period
	NVAR StimulatorFreq = root:Packages:tClamp16:StimulatorFreq
	NVAR StimulatorSamplingNpnts = root:Packages:tClamp16:StimulatorSamplingNpnts
	NVAR StimulatorAcqTime = root:Packages:tClamp16:StimulatorAcqTime
	
	StimulatorFreq = 1/(1E-06*StimulatorITC16Period)	
	StimulatorAcqTime = StimulatorSamplingNpnts/StimulatorFreq
	
	If(StimulatorFreq > 200001)
		DoAlert 0, "Too Much Freq!!"
	endif
	
	tClamp16RescaleDigitalOut()
end

Function tClamp16RescaleDigitalOut()
	NVAR StimulatorFreq = root:Packages:tClamp16:StimulatorFreq	
	Wave DigitalOut = $("root:Packages:tClamp16:DigitalOut")
	SetScale/P x 0, (1/StimulatorFreq), "s", DigitalOut
End

Function tClamp16StimulatorRun(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ISI = root:Packages:tClamp16:TimerISI
	tClamp16ApplyStimulatorSetting()
	SetBackground  tClamp16StimulatorBGFlowControl()
	tClamp16TimerReset("")
	CtrlBackground period=ISI,dialogsOK=1,noBurst=1,start
End

Function tClamp16StimulatorBGFlowControl()
	NVAR ISI = root:Packages:tClamp16:StimulatorISI
	NVAR Counter = root:Packages:tClamp16:StimulatorCounter
	NVAR CounterLimit = root:Packages:tClamp16:StimulatorCounterLimit
	NVAR TimerISITicks = root:Packages:tClamp16:TimerISITicks
	
	Variable now = ticks

	If(ISI <= (now - TimerISITicks)|| Counter ==0)
		TimerISITicks = now

		tClamp16StimulatorMainProtocol()
		Execute/Q "tClamp16StimStimAndSamlple()"
		
		Counter += 1
	endIf

	tClamp16TimerUpdate()
	
	If(Counter < CounterLimit || CounterLimit == 0)
		return 0
	else
		return 1
	endif
End

Function tClamp16StimulatorMainProtocol()
	Wave DigitalOut = $"root:Packages:tClamp16:DigitalOut"	//Output Wave for DigitalOut
	Wave FIFOOut = $"root:Packages:tClamp16:FIFOOut"

	DigitalOut = 0

	Variable i = 0
	For(i = 0; i < 4; i += 1)
		NVAR Delay = $("root:Packages:tClamp16:StimulatorDelay" + Num2str(i))
		NVAR Interval = $("root:Packages:tClamp16:StimulatorInterval" + Num2str(i))
		NVAR Train = $("root:Packages:tClamp16:StimulatorTrain" + Num2str(i))
		NVAR Duration = $("root:Packages:tClamp16:StimulatorDuration" + Num2str(i))

		Variable j = 0
		For(j = 0; j < Train; j += 1)
			Variable initialp = trunc((Delay + Interval*j)/deltax(DigitalOut))
			Variable endp = initialp + trunc(Duration/deltax(DigitalOut))
			DigitalOut[initialp, endp] += 2^i
		endFor
	endFor

	FIFOOut = DigitalOut
end

Proc tClamp16StimStimAndSamlple()
	silent 1	// retrieving data...
	
	//Global Variables
	String Period = "root:Packages:tClamp16:StimulatorITC16Period"
	String Freq = "root:Packages:tClamp16:StimulatorFreq"
	//Global Waves	
	String FIFOout = "root:Packages:tClamp16:FIFOout"
	String FIFOin = "root:Packages:tClamp16:FIFOin"

	ITC16SetAll 0,0,0,0,0,0		// bug!! don't pre-set Digital output channels. If they are set, all digial output channels will unintendedly fire.
	ITC16seq "D", "0"

	PauseUpdate

	ITC16StimandSample $FIFOout, $FIFOin, $Period, 6, 0
    
      ResumeUpdate
endMacro

Function tClamp16UseStimulator()
	Wave DigitalOut = $"root:Packages:tClamp16:DigitalOut"	//Output Wave for DigitalOut
	DigitalOut = 0

	Variable i = 0
	For(i = 0; i < 4; i += 1)
		NVAR Delay = $("root:Packages:tClamp16:StimulatorDelay" + Num2str(i))
		NVAR Interval = $("root:Packages:tClamp16:StimulatorInterval" + Num2str(i))
		NVAR Train = $("root:Packages:tClamp16:StimulatorTrain" + Num2str(i))
		NVAR Duration = $("root:Packages:tClamp16:StimulatorDuration" + Num2str(i))

		Variable j = 0
		For(j = 0; j < Train; j += 1)
			Variable initialp = trunc((Delay + Interval*j)/deltax(DigitalOut))
			Variable endp = initialp + trunc(Duration/deltax(DigitalOut))
			DigitalOut[initialp, endp] += 2^i
		endFor
	endFor
end

Function tClamp16StimulatorReset(ctrlName) : ButtonControl
	String ctrlName

	NVAR Counter = root:Packages:tClamp16:StimulatorCounter
	NVAR CounterLimit = root:Packages:tClamp16:StimulatorCounterLimit
	
	Counter = 0
	CounterLimit = 0
End

// Stimulator End

///////////////////////////////////////////////////////////////////
// Timer Panel

Function tClamp16_TimerPanel()
	NewPanel/N=tClamp16TimerPanel/W=(12,57,291,154)
	ValDisplay ValdisptClampETime,pos={5,5},size={100,13},title="ET (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:ElapsedTime"
	ValDisplay ValdisptClampTimeFromTick,pos={5,29},size={100,13},title="TTime (s)",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:TimeFromTick"
	ValDisplay ValdisptClampOscilloCounter,pos={5,55},size={100,13},title="Oscillo ",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:OscilloCounter"
	ValDisplay ValdisptClampSealCounter,pos={5,78},size={100,13},title="Seal",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:SealTestCounter"
	ValDisplay ValdisptClampStimCounter,pos={124,55},size={120,13},title="Stimulator",limits={0,0,0},barmisc={0,1000},value= #"root:Packages:tClamp16:StimulatorCounter"
	SetVariable SetvartClampTimerISI,pos={124,3},size={120,16},limits={1,inf,1},title="TimerISI (tick)",value= root:Packages:tClamp16:TimerISI
	Button BttClampTimeStart,pos={124,25},size={50,20},proc=tClamp16TimerStart,title="Run"
	Button BttClampBackGStop,pos={174, 25},size={50,20},proc=tClamp16BackGStop,title="Stop"
	Button BttClampTimerReset,pos={224, 25},size={50,20},proc=tClamp16TimerReset,title="Reset"
end

Function tClamp16_DisplayTimer()
	If(WinType("tClamp16TimerPanel") == 7)
		DoWindow/HIDE = ? $("tClamp16TimerPanel")
		If(V_flag == 1)
			DoWindow/HIDE = 1 $("tClamp16TimerPanel")
		else
			DoWindow/HIDE = 0/F $("tClamp16TimerPanel")
		endif
	else	
		tClamp16_TimerPanel()
	endif
End

Function tClamp16_HideTimer()
	If(WinType("tClamp16TimerPanel"))
		DoWindow/HIDE = 1 tClamp16TimerPanel
	endif
End

Function tClamp16TimerUpdate()
	NVAR timefromtick = root:Packages:tClamp16:TimeFromTick
	NVAR elapsedtime = root:Packages:tClamp16:ElapsedTime
	Variable now
	Variable delta
	now = ticks/60
	delta = now - timefromtick
	elapsedtime += delta
	timefromtick = now
	return 0
end

Function tClamp16TimerStart(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ElapsedTime = root:Packages:tClamp16:ElapsedTime
	NVAR TimeFromTick = root:Packages:tClamp16:TimeFromTick
	NVAR ISI = root:Packages:tClamp16:TimerISI
	TimeFromTick = ticks/60
	SetBackground tClamp16TimerUpdate()
	CtrlBackground period = ISI, dialogsOK = 1, noBurst = 1,start
End

Function tClamp16BackGStop(ctrlName) : ButtonControl
	String ctrlName
	
	CtrlBackground stop
	
	If(StringMatch(ctrlName, "BttClampBackGStop_tab1"))
		NVAR NumTrial = root:Packages:tClamp16:NumTrial
		NumTrial += 1
	endIf
End

Function tClamp16TimerReset(ctrlName) : ButtonControl
	String ctrlName
	
	NVAR ElapsedTime = root:Packages:tClamp16:ElapsedTime
	NVAR TimeFromTick = root:Packages:tClamp16:TimeFromTick
	NVAR OscilloCounter = root:Packages:tClamp16:OscilloCounter
	NVAR SealTestCounter = root:Packages:tClamp16:SealTestCounter
	NVAR StimulatorCounter = root:Packages:tClamp16:StimulatorCounter
	NVAR TimerISITicks = root:Packages:tClamp16:TimerISITicks
	
	ElapsedTime = 0
	TimeFromTick = ticks/60
	TimerISITicks = ticks
	OscilloCounter = 0
	SealTestCounter = 0
	StimulatorCounter = 0
End

//end Timer Panel

///////////////////////////////////////////////////////////////////
// Utilites

Function tClamp16_Execute(StringToBeExecuted)
	String StringToBeExecuted

	Execute/Q StringToBeExecuted
end

Function tClamp16BitCoder(bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7)
	Variable bit0, bit1, bit2, bit3, bit4, bit5, bit6, bit7
	
	Variable vOut = 0

	bit0 = trunc(bit0)
	If(bit0)
		vOut += 2^0
	endif
	
	bit1 = trunc(bit1)
	If(bit1)
		vOut += 2^1
	endif
	
	bit2 = trunc(bit2)
	If(bit2)
		vOut += 2^2
	endif
	
	bit3 = trunc(bit3)
	If(bit3)
		vOut += 2^3
	endif

	bit4 = trunc(bit4)
	If(bit4)
		vOut += 2^4
	endif

	bit5 = trunc(bit5)
	If(bit5)
		vOut += 2^5
	endif

	bit6 = trunc(bit6)
	If(bit6)
		vOut += 2^6
	endif

	bit7 = trunc(bit7)
	If(bit7)
		vOut += 2^7
	endif

	return vOut
end

Function tClamp16BitUpdate(srcStr, destStr, ForTimes)
	String srcStr, destStr
	Variable ForTimes

	NVAR vOut = $destStr
	vOut = 0
	
	Variable i = 0
	For(i = 0; i < ForTimes; i +=1)
		NVAR bit = $(srcStr + Num2str(i))
		bit = trunc(bit)
		If(bit)
			vOut += 2^i
		endif
	endfor
end