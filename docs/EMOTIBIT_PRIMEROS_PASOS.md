# Primer contacto con el EmotiBit

Guía para conectar el EmotiBit real por primera vez y analizar qué entrega. Todo se hace desde el computador con la herramienta `emotibit` del repo, sin la app móvil.

## 1. Preparar el dispositivo

1. **Cargar la batería** con el cable USB.
2. **Configurar el WiFi en la microSD.** El EmotiBit lee la red desde un archivo `config.txt` en la raíz de la tarjeta:
   ```json
   {"WifiCredentials":[{"ssid":"NOMBRE_DE_TU_RED","password":"TU_CLAVE"}]}
   ```
   - Debe ser una red de **2,4 GHz**. El ESP32 del EmotiBit no ve redes de 5 GHz.
   - Evita redes de invitados o corporativas: suelen aislar a los dispositivos entre sí y la conexión falla.
   - Alternativa: comparte internet desde tu celular y conecta **el EmotiBit y el computador** a ese hotspot.
   - Confirma el formato exacto en la guía oficial (EmotiBit Docs, *Getting Started*), por si cambió con la versión de firmware.
3. Inserta la microSD y **enciende** el EmotiBit. Espera a que el LED indique que se conectó al WiFi (el significado de cada LED está en la documentación oficial).
4. **El computador tiene que estar en la misma red** que el EmotiBit.
5. **Cierra el EmotiBit Oscilloscope** si lo tienes abierto: el EmotiBit atiende a un solo programa a la vez.

## 2. Buscarlo

```bash
make scan
```

Si aparece, anota su **ID** y su **IP**. La primera vez, macOS puede preguntar si permites conexiones entrantes a `dart`: responde **Permitir**.

Si no aparece:
- Prueba con la IP directa: `make scan IP=192.168.x.x`. La IP aparece en la configuración de tu router o en la lista de dispositivos del hotspot.
- Activa el diagnóstico para ver cada mensaje: `make scan ARGS=-v`.
- Revisa que el EmotiBit funcione con el software oficial (**EmotiBit Oscilloscope**). Si ahí tampoco aparece, el problema es de red o de configuración del dispositivo, no de nuestro código.

## 3. Ver en vivo qué envía

```bash
make monitor            # tabla que se actualiza cada 2 s
make monitor ARGS=-v    # además muestra todo el intercambio de conexión (diagnóstico)
```

La tabla muestra cada tipo de señal (tag), cuántas muestras llegan, la **frecuencia real (Hz)**, los valores mínimo, medio y máximo, y los **paquetes perdidos**. Cuando aparece un tipo de paquete nuevo, se anuncia en pantalla.

## 4. Grabar sesiones

```bash
make record                        # graba hasta Ctrl+C en recordings/<fecha-hora>/
make record ARGS="--seconds 300"   # graba 5 minutos
```

Cada sesión queda en `recordings/<fecha-hora>/`:
- `raw.csv`: paquetes tal cual los envía el EmotiBit (mismo formato que su microSD).
- `sync.csv`: correspondencia entre el reloj del EmotiBit y la hora real.
- `resumen.txt`: la tabla final de estadísticas.

`recordings/` está excluido de git porque son datos fisiológicos.

Para analizar una grabación después, o un archivo de la microSD del EmotiBit:
```bash
make emotibit ARGS="analyze recordings/2026-11-25T10-00-00/raw.csv"
```

## 5. Checklist de validación

Estas respuestas cierran los puntos "no verificados" de [ARCHITECTURE.md](ARCHITECTURE.md). Resultados de la primera sesión (25-11-2026, 5 min en reposo, `recordings/2026-11-25T15-43-29`):

- [x] **¿Conecta?** Sí. `scan`, `monitor` y `record` funcionan sin cambios en el código.
- [x] **ID del dispositivo:** `MD-V7-0000829` (HW V07a).
- [x] **Señales que llegan:** EA, EL, PG, PI, PR, AX–AZ, GX–GZ, MX–MZ, T1, TH, HR, BI, SA, SR, SF, B%, BV y EM. No llegan T0, H0 ni ER.
- [x] **Frecuencias reales:** EDA 15 Hz, PPG 25 Hz, IMU 25 Hz, temperatura 7,5 Hz.
- [x] **Temperatura:** llega como T1 y TH (termopila), no como T0.
- [x] **HR y BI:** los calcula y envía el EmotiBit (1 por segundo). Tienen valores aislados irreales que hay que filtrar.
- [ ] **Pérdida de paquetes:** cerca del router, 0,5 a 0,8 %. Falta probar lejos del router y con el brazo en movimiento.
- [ ] **Estabilidad:** falta una grabación de 10 a 15 minutos. El dispositivo se reinició dos veces al manipularlo; puede ser el conector de la batería.
- [x] **Sincronización de reloj:** llega `RD` cada ~5,1 s. El dispositivo deja nuestros `TL`/`TU` en el flujo y los confirma con `AK`.
- [ ] **Batería:** B% llega cada ~5 s. Bajó ~17 % en 23 minutos sin cargar; falta medirlo en una sesión de 15 minutos.
- [ ] **Respaldo en microSD:** pendiente.
- [ ] **DataParser oficial:** falta comprobar que abre nuestro `raw.csv`.

Sesiones sugeridas para el análisis:
1. ~~5 minutos en reposo (sentado, brazo quieto).~~ Hecha.
2. 5 minutos con movimiento (caminar, mover el brazo).
3. 2 minutos con un estímulo leve (por ejemplo, respirar rápido o un ruido fuerte) para ver la respuesta de EDA.
4. 15 minutos seguidos, sin cargar, para estabilidad y batería.

Guarda las carpetas de `recordings/`: son los primeros datos de prueba.

## 6. Lecciones de la primera sesión

- **Firmware:** el instalador oficial (FirmwareInstaller) no detectó la placa. Se instaló el firmware 1.14.0 a mano con el `esptool` que viene incluido en el software oficial. No hace falta un driver USB.
- **Ubicación del sensor:** la EDA necesita buen contacto de los electrodos. En la parte superior del brazo no hubo contacto y la EDA quedó fija en ~0,0302 µS. En la yema del dedo índice funcionó. Si la EDA no se mueve de ese valor, revisa el contacto.
- **Seguridad:** el firmware muestra la clave del WiFi en texto plano por el puerto serie USB. No compartas capturas ni registros del monitor serie.
