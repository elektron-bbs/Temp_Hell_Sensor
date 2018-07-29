'*******************************************************************************
'*    Description : WS2000 Sensor Temperatur, Feuchte und Helligkeit mit       *
'*    SHT21 + TSL4531 + Aurel TX SAW MID 3V Transmitter                        *
'*    Revision      : 2.0                                                      *
'*    Controller    : ATmega48PA-PU                                            *
'*    Stromaufnahme : ca. 6 µA                                                 *
'*    Compiler      : BASCOM-AVR  2.0.7.8                                      *
'*    Author        : UB , 2015                                                *
'*    Web           : HTTP://WWW.Elektron-BBS.de                               *
'*******************************************************************************
$regfile = "m48pdef.dat"
$crystal = 1000000
$hwstack = 40
$swstack = 40
$framesize = 40
Stop Ac                                                     ' Strom sparen
Stop Adc                                                    ' Strom sparen

'****************************** Timer 2 ****************************************
Config Timer2 = Timer , Async = On , Prescale = 1024        ' 8 Sekunden
Enable Timer2
Dim Count As Byte

'******************************** I2C ******************************************
$lib "i2c_twi.lbx"                                          ' we do not use software emulated I2C but the TWI
Config Scl = Portc.5                                        ' I2C Clock
Config Sda = Portc.4                                        ' I2C Data
I2cinit                                                     ' I2C-Bus initialisieren

'************************* ports for connection ********************************
Config Portb.0 = Output : Tx433 Alias Portb.0               ' Data Sendemodul 433 MHz
Config Portc.0 = Output : Tsl_vdd Alias Portc.0             ' Betriebsspannung TSL4531

'*************************** ungenutze Ports ***********************************
Config Portb.1 = Input : Portb.1 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portb.2 = Input : Portb.2 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portb.3 = Input : Portb.3 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portb.4 = Input : Portb.4 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portb.5 = Input : Portb.5 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portc.1 = Input : Portc.1 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portc.2 = Input : Portc.2 = 1                        ' Port als Eingang, Pullup eingeschaltet
Config Portc.3 = Input : Portc.3 = 1                        ' Port als Eingang, Pullup eingeschaltet

'************************* Variablen TX 433 MHz ********************************
Dim Tx_dbl As Double                                        ' 64 Bit Sendepuffer
Dim Tx_bit As Byte                                          ' zu sendendes Bit
Dim Tx_bit_nr As Byte                                       ' Nummer zu sendendes Bit
Dim Tx_bit_anzahl As Byte                                   ' Anzahl zu sendende Bits
Dim Tx_byte As Byte                                         ' zu sendendes Byte
Dim Tx_byte_nr As Byte                                      ' Nummer zu sendendes Byte
Dim Tx_byte_anzahl As Byte                                  ' Anzahl zu sendende Bytes
Dim Check As Byte                                           ' Prüfsumme XOR Typ bis Check muss 0 ergeben
Dim Ersumme As Byte                                         ' Prüfsumme errechnet
Dim Potenz As Byte                                          ' Faktor Helligkeit
Dim S_adresse_hell As Byte                                  ' Sensoradresse Helligkeit
Dim S_adresse_temp As Byte                                  ' Sensoradresse Temperatur/Feuchte

'*************************** Variablen SHT21 ***********************************
Dim Trigger As Byte                                         ' Temperatur oder Feuchte
Dim Temperature As Integer                                  ' Temperatur
Dim Humidity As Integer                                     ' Feuchte

'************************** Variablen TSL4531 **********************************
'Const Tsl_adress_w = &H52                                   ' Write Address
Const Tsl_adress_w = &H72                                   ' Write Address
'Const Tsl_adress_r = &H53                                   ' Read Address
Const Tsl_adress_r = &H73                                   ' Write Address
Dim Lux As Dword                                            ' Helligkeitswert
Dim Tsl_raw As Word                                         ' Werte vom ADC TSL4531
Dim Tsl_lsb As Byte At Tsl_raw Overlay                      ' low Byte
Dim Tsl_msb As Byte At Tsl_raw + 1 Overlay                  ' high Byte
Dim Tsl_faktor As Byte                                      ' Faktor für Umrechnung ADC-Werte
Tsl_faktor = 1                                              ' Default-Faktor TSL4531

'***************************** Temporär ****************************************
Dim U As Byte , X As Byte , Y As Byte , Z As Byte
Dim D As Dword                                              ' 0 to 4294967295
Dim L As Long                                               ' -2147483648 to 2147483647
Dim W As Word
Dim Ar(10) As Byte

Enable Interrupts                                           ' Interrupts einschalten

'*************************** H A U P T P R O G R A M M *************************
Do
   Select Case Count
      Case 1                                                ' Helligkeit messen
         Timer2 = &HE0                                      ' Timer auf 1 Sekunde bis Overflow
         Set Tsl_vdd                                        ' Betriebsspannung TSL4531 einschalten
         'Sensoren Adressen von Jumperstellung übernehmen
         Config Portd = Input                               ' Port als Eingänge
         Portd = 255                                        ' Pullups einschalten
         Nop                                                ' kurz warten (SYNC LATCH)
         X = Pind                                           ' Jumperstellung übernehmen
         'Jumper gegen GND, gesteckt = Bit auf 0, offen = Bit auf 1
         'Pind.0 - Jumper 1 (K1) Adresse Helligkeit
         'Pind.1 - Jumper 2 (K2) Adresse Helligkeit
         'Pind.2 - Jumper 3 (K3) Adresse Helligkeit
         S_adresse_hell = X And &B00000111                  ' Adresse Helligkeitssensor (untere 3 Bit) übernehmen
         'Pind.5 - Jumper 1 (K4) Adresse Temperatur/Feuchte
         'Pind.6 - Jumper 2 (K5) Adresse Temperatur/Feuchte
         'Pind.7 - Jumper 3 (K6) Adresse Temperatur/Feuchte
         Shift X , Right , 5                                ' obere 3 Bit nach unten schieben
         S_adresse_temp = X And &B00000111                  ' Adresse Temp-/Feuchtesensor (untere 3 Bit) übernehmen
         Portd = 0                                          ' Pullups ausschalten
         Config Portd = Output                              ' Port als Ausgang
         'TSL4531 Messung einleiten
         Select Case Tsl_raw
            Case 0 To 32767
               If Tsl_faktor >= 2 Then
                  Tsl_faktor = Tsl_faktor / 2
                  Gosub Tsl_wr_time_r81                     ' Messzeit umschalten
               End If
            Case 65535                                      ' Überlauf
               If Tsl_faktor < 4 Then                       ' maximaler Faktor 4
                  Tsl_faktor = Tsl_faktor * 2
                  Gosub Tsl_wr_time_r81                     ' Messzeit umschalten
               End If
         End Select
         I2cstart                                           ' Initialisieren
         I2cwbyte Tsl_adress_w
         I2cwbyte &H80                                      ' Command Adresse 0 = Control
         I2cwbyte &H02                                      ' Control= &H02 = Run a single ADC cycle and return to PowerDown
         I2cstop
      Case 2
         'TSL4531 Messwerte holen und senden
         I2cstart
         I2cwbyte Tsl_adress_w                              ' Daten holen
         I2cwbyte &H84                                      ' Command Adresse 4 = Data LOW Register
         I2crepstart
         I2cwbyte Tsl_adress_r
         I2crbyte Tsl_lsb , Ack                             ' TSL_lsb und acknowledge
         I2crbyte Tsl_msb , Nack                            ' TSL_msb und noacknowledge
         I2cstop
         Reset Tsl_vdd                                      ' Betriebsspannung TSL4531 ausschalten
         If Tsl_raw < 65535 Then                            ' wenn kein Overflow, dann
            Lux = Tsl_raw * Tsl_faktor                      ' Messwert übernehmen
         End If
         D = Lux                                            ' Wert übernehmen
         Select Case D
            Case 0 To 4095                                  ' es werden 12 Bit gesendet
               Potenz = 0                                   ' 0 = Faktor 1
            Case 4096 To 40950
               Potenz = 1                                   ' 1 = Faktor 10
               D = D / 10
            Case 40951 To 409500
               Potenz = 2                                   ' 2 = Faktor 100
               D = D / 100
            Case Else
               Potenz = 3                                   ' 3 = Faktor 1000
               D = D / 1000
         End Select
         Ar(1) = 5                                          ' Sensortyp 5 - Helligkeit (S2500H)
         Ar(2) = S_adresse_hell                             ' Sensoradresse übernehmen
         W = Loww(d)                                        ' untere 16 Bit übernehmen
         X = Low(w)                                         ' untere 8 bit aus Helligkeit übernehmen
         Ar(3) = X And &B00001111                           ' LSN Bit 0-3 übernehmen (obere 4 Bit auf 0 setzen)
         Shift X , Right , 4                                ' obere 4 Bit nach rechts schieben
         Ar(4) = X                                          ' MID Bit 4-7 übernehmen
         X = High(w)                                        ' obere 8 bit aus Word übernehmen
         Ar(5) = X And &B00001111                           ' MSN Bit 8-11 übernehmen (obere 4 Bit auf 0 setzen)
         Ar(6) = Potenz                                     ' Faktor übernehmen
         Tx_bit_anzahl = 50                                 ' Helligkeit (S2500H)
         Tx_byte_anzahl = 6                                 ' Anzahl zu sendende Bytes
         Gosub Tx_433_send                                  ' Daten senden
      Case 3
         'SHT21 Temperatur messen
         Trigger = &HF3                                     ' SHT21 Trigger Temperaturmessung
         Gosub Sht21_mess                                   ' SHT21 Messung starten
      Case 4
         'SHT21 Temperaturwerte holen
         Gosub Sht21_read                                   ' SHT21 Werte holen
         'SHT21 Feuchte messen
         Trigger = &HF5                                     ' SHT21 Trigger Feuchtemessung
         Gosub Sht21_mess                                   ' SHT21 Messung starten
      Case 5
         Timer2 = S_adresse_temp * 16                       ' 8 - 0 bis 3,5 Sekunden, je nach Adresse
         'SHT21 Feuchtewerte holen
         Gosub Sht21_read                                   ' SHT21 Werte holen
         If Temperature >= -300 Then                        ' Fehler abfangen
            If Humidity >= 1 Then                           ' Fehler abfangen
               Ar(1) = 1                                    ' Sensortyp 1 - Thermo/Hygro (AS2000, ASH2000, S2000, S2001A, S2001IA, ASH2200, S300IA)
               Ar(2) = S_adresse_temp                       ' Sensoradresse Temperatur übernehmen
               W = Temperature                              ' Temperatur übernehmen
               If Temperature < 0 Then
                  Ar(2).3 = 1                               ' Bit 20 Vorzeichen negativ
                  W = Temperature * -1                      ' Temperaturwert umkehren
               End If
               Gosub Tx_wert                                ' Temperatur umrechnen
               Ar(3) = Z : Ar(4) = Y : Ar(5) = X            ' Bit 22-35 Temperatur in Array übernehmen
               W = Humidity                                 ' Feuchte übernehmen
               Gosub Tx_wert                                ' Feuchte umrechnen
               Ar(6) = Z : Ar(7) = Y : Ar(8) = X            ' Bit 37-50 Feuchte in Array übernehmen
               Tx_bit_anzahl = 60                           ' Thermo/Hygro (AS2000, ASH2000, S2000, S2001A, S2001IA, ASH2200, S300IA)
               Tx_byte_anzahl = 8                           ' Anzahl zu sendende Bytes
               Gosub Tx_433_send                            ' Daten senden
            End If
         End If
   End Select

   Incr Count
   '22 * 8 Sek = 176 Sekunden + 1 (Case 1) = 177 Sekunden - Adresse * 0,5 Sekunden (Case 5)
   If Count >= 23 Then : Count = 0 : End If                 ' 177 - Adresse * 0,5 Sekunden
   Config Powermode = Powersave
Loop

End

'************************** U N T E R P R O G R A M M E ************************
'senden dauert: 62,22 mS (Helligkeit), 74,42 mS (Thermo/Hygro)
Tx_433_send:
   Tx_dbl = 0                                               ' alle Bits auf 0 setzen
   X = 10                                                   ' 10 Bit Präambel
   Do                                                       ' Bit 10 bis Anzahl Step 5 muß 1 sein
      Tx_dbl.x = 1                                          ' Bit auf 1 setzen
      X = X + 5                                             ' Array beginnt bei 1
   Loop Until X > Tx_bit_anzahl
   'Bits übernehmen
   Check = 0                                                ' Checksumme zurück setzen
   Ersumme = 0                                              ' Prüfsumme zurück setzen
   Tx_byte_nr = 0
   Do                                                       ' Sensortyp, Adresse und Werte senden
      Incr Tx_byte_nr                                       ' beginnt mit 1
      Tx_byte = Ar(tx_byte_nr)                              ' Byte übernehmen
      Gosub Tx_433_byte                                     ' Bit 0-3 übernehmen
   Loop Until Tx_byte_nr >= Tx_byte_anzahl                  ' fertig
   Incr Tx_byte_nr                                          ' nächstes Byte
   Tx_byte = Check                                          ' Checkbyte übernehmen
   Gosub Tx_433_byte                                        ' Byte übernehmen
   Ersumme = Ersumme + 5                                    ' Prüfsumme errechnen
   Tx_byte = Ersumme And &B00001111                         ' obere 4 Bit auf 0 setzen
   Incr Tx_byte_nr                                          ' nächstes Byte
   Gosub Tx_433_byte                                        ' Byte senden
   'Bits senden
   X = 0                                                    ' Beginne mit Bit 0
   Do
      If Tx_dbl.x = 1 Then                                  ' 1 senden
         Set Tx433                                          ' Ausgang high
         Waitus 366                                         ' 366 µS warten
         Reset Tx433                                        ' Ausgang low
      'Waitus 854                                            ' 854 µS warten
         Waitus 780                                         ' 854 µS warten, Rest braucht Programm
      Else                                                  ' 0 senden
         Set Tx433                                          ' Ausgang high
         Waitus 854                                         ' 854 µS warten
         Reset Tx433                                        ' Ausgang low
      'Waitus 366                                            ' 366 µS warten
         Waitus 304                                         ' 366 µS warten, Rest braucht Programm
      End If
      Incr X                                                ' nächstes Bit
   Loop Until X > Tx_bit_anzahl                             ' Ende mit gesetzter Anzahl Bits
Return

Tx_433_byte:
   Tx_bit_nr = Tx_byte_nr * 5                               ' 5, 10, 15...
   Tx_bit_nr = Tx_bit_nr + 6                                ' 11, 16, 21...
   X = 0
   Do
      Tx_dbl.tx_bit_nr = Tx_byte.x                          ' Bit aus Byte übernehmen
      Incr Tx_bit_nr : Incr X                               ' nächstes Bit
   Loop Until X >= 4                                        ' 4 Bit
   Check = Check Xor Tx_byte                                ' Check
   Ersumme = Ersumme + Tx_byte                              ' Prüfsumme bilden
Return

Tsl_wr_time_r81:
   X = Tsl_faktor                                           ' Configuration Register= &H00 = Multiplier x1
   Shift X , Right , 1                                      ' Configuration Register= &H01 = Multiplier x2
   I2cstart                                                 ' Configuration Register= &H02 = Multiplier x4
   I2cwbyte Tsl_adress_w
   I2cwbyte &H81                                            ' Command Adresse 1 = Configuration Register
   I2cwbyte X
   I2cstop
Return

Sht21_mess:                                                 ' SHT21 Messung starten
   I2cstart
   I2cwbyte &H80                                            ' I2C address + write
   I2cwbyte Trigger                                         ' Trigger measurement
   Waitus 20
   I2cstop
Return

Sht21_read:                                                 ' SHT21 Werte holen
   I2cstart
   I2cwbyte &H81                                            ' I2C address + read
   I2crbyte Ar(1) , Ack                                     ' receiving the high byte
   I2crbyte Ar(2) , Ack                                     ' receiving the low byte
   I2crbyte Ar(3) , Nack                                    ' receiving CRC
   I2cstop                                                  ' end of the contact
   'Calculate the CRC8 for SHT21
   Loadadr Ar(1) , Z
   $asm
      LDI R16,$02                                           'Number of bytes to calculate.
      CLR R24                                               'CRC value.
      LDI R22,$31                                           'POLYNOMIAL = 0x131 P(x)=x^8+x^5+x^4+1 = 1_0011_0001
Sht21crc1:
      LD R25,Z+                                             'To read the calculated byte.
      EOR R24,R25                                           'CRC = CRC EXOR ar(x)
      LDI R17,$08
Sht21crc2:
      LSL R24                                               'CRC to the left I 1bit shift.
      BRcc Sht21crc3                                        'bit7 of shift before the CRC [1]?
      EOR R24,R22                                           'CRC = CRC EXOR &H31
Sht21crc3:
      DEC R17
      BRNE Sht21crc2                                        '8-bit or end?
      DEC R16
      BRNE Sht21crc1                                        'Number of bytes to calculate is over?
      ADIW R30,1                                            'Stores the calculated CRC value for the next received byte CRC.
      ST Z,R24
   $end Asm
   If Ar(3) = Ar(4) Then                                    ' CRC Check OK
      Ar(2) = Ar(2) And &B1111_1100                         ' Mask the status bit.
      W = Makeint(ar(2) , Ar(1))                            ' Convert 2 byte in one word.
      If Trigger = &HF3 Then                                ' Trigger T measurement
         L = 17572 * W                                      ' Calculation of temperature conversion
         Temperature = Highw(l)                             ' 1/2^16
         Temperature = Temperature - 4685                   ' Calculation of temperature conversion
         Temperature = Temperature / 10                     ' Calculation of temperature conversion
      End If
      If Trigger = &HF5 Then                                ' Trigger RH measurement
         L = 1250 * W                                       ' Calculation of humidity conversion
         Humidity = Highw(l)                                ' 1/2^16
         Humidity = Humidity - 60                           ' Calculation of humidity conversion
      End If
   End If
Return

Tx_wert:
   U = 0
   While W >= 100                                           ' solange Wert größer X
      W = W - 100                                           ' Zehnerpotenz subtrahieren
      Incr U                                                ' dann Zaehler erhöhen
   Wend
   X = U                                                    ' Hunderter
   U = 0
   While W >= 10                                            ' solange Wert größer X
      W = W - 10                                            ' Zehnerpotenz subtrahieren
      Incr U                                                ' dann Zaehler erhöhen
   Wend
   Y = U                                                    ' Zehner
   Z = Low(w)                                               ' Einer
Return