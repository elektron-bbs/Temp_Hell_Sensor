# Funk-Temperatur-, Feuchte- und Helligkeits-Sensor
Dieser Funk-Sensor überträgt die Werte der Temperatur und relativen Feuchte eines Sensors vom Typ SHT21.
Außerdem wird der Helligkeitswert eines Sensors vom Typ TSL4531 übertragen. Der Messbereich beträgt 0 bis 220000 Lux.
Verwendet wird ein Funkprotokoll der WS2000/WS7000-Serie. Dieses Protokoll kann vom SIGNALduino oder auch CUL empfangen und in FHEM dekodiert werden.
Zum Einsatz kommt ein ATMega48. Die Software wurde unter BASCOM erstellt.

Sowohl für den Temperatur- und Feuchtesensor als auch für den Helligkeitssensor können individuelle Adressen im Bereich von 0 bis 7 mittels Jumpern eingestellt werden.

Versorgt wird der Sensor von 2 Zellen vom Typ AA. Die Stromaufnahme liegt im Bereich weniger Mikroampere.
Bei mir funktioniert der Sensor bereits seit über 3 Jahren mit dem ersten Batteriesatz.
