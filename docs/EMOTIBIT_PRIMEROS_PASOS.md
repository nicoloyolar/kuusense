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

## 5. Qué revisar mañana (checklist)

Estas respuestas cierran los puntos "no verificados" de [ARCHITECTURE.md](ARCHITECTURE.md):

- [ ] **¿Conecta?** `scan` lo encuentra y `monitor` recibe datos.
- [ ] **ID del dispositivo:** ¿qué formato tiene?
- [ ] **Señales que llegan:** ¿cuáles tags aparecen? En el simulador son EA, PI, PR, PG, AX–AZ, GX–GZ, T0, HR, BI y B%. ¿Llegan MX–MZ, TH, T1, H0, EL o ER?
- [ ] **Frecuencias reales:** EDA ~15 Hz, PPG ~25 Hz, IMU ~25 Hz, temperatura ~7,5 Hz.
- [ ] **Temperatura:** ¿viene como T0, TH o T1?
- [ ] **HR y BI (derivados):** ¿el EmotiBit los calcula y envía, o hay que calcularlos nosotros?
- [ ] **Pérdida de paquetes:** cerca del router, lejos del router, con el brazo en movimiento.
- [ ] **Estabilidad:** grabación de 10 a 15 minutos sin cortes. Si se desconecta, ¿cuánto tarda en notarlo?
- [ ] **Sincronización de reloj:** con `-v`, ¿aparecen mensajes `RD` cada ~5 s? ¿El dispositivo responde algo a nuestros `TL`/`TU`?
- [ ] **Batería:** ¿llega B%? ¿Cuánto baja en 15 minutos?
- [ ] **Respaldo en microSD:** graba en paralelo en la microSD (desde el Oscilloscope o con el botón, según la documentación) y compara con `analyze`.

Sesiones sugeridas para el análisis:
1. 5 minutos en reposo (sentado, brazo quieto).
2. 5 minutos con movimiento (caminar, mover el brazo).
3. 2 minutos con un estímulo leve (por ejemplo, respirar rápido o un ruido fuerte) para ver la respuesta de EDA.

Guarda las carpetas de `recordings/`: sirven para ajustar el simulador a la realidad y como primeros datos de prueba.
