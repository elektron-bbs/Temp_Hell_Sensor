# Funk-Temperatur-, Feuchte- und Helligkeits-Sensor
Dieser Funk-Sensor überträgt die Werte der Temperatur und relativen Feuchte eines Sensors vom Typ SHT21.
Außerdem wird der Helligkeitswert eines Sensors vom Typ TSL4531 übertragen. Der Messbereich beträgt 0 bis 220000 Lux.
Verwendet wird ein Funkprotokoll der WS2000/WS7000-Serie. Dieses Protokoll kann vom SIGNALduino oder auch CUL empfangen und in FHEM dekodiert werden.
Zum Einsatz kommt ein ATMega48. Die Software wurde unter BASCOM erstellt.

Sowohl für den Temperatur- und Feuchtesensor als auch für den Helligkeitssensor können individuelle Adressen im Bereich von 0 bis 7 mittels Jumpern eingestellt werden.

Versorgt wird der Sensor von 2 Zellen vom Typ AA. Die Stromaufnahme liegt im Bereich weniger Mikroampere.
Der erste Satz Mignonzellen musste nach etwa 7,5 Jahren ausgetauscht werden, weil Temperatur- und Feuchtemessung aussetzte.
Die Batteriespannung lag zu diesem Zeitpunkt bei ca. 2,0 Volt. Das passt auch ganz gut zu den Angaben im Datenblatt des SHT21, wo als minimale Versorgungsspannung 2,1 Volt angegeben werden.
