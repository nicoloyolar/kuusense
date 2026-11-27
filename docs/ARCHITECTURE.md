# KúuSense — Arquitectura

KúuSense anticipa episodios de desregulación emocional en NNA con TEA usando las señales fisiológicas de un **EmotiBit**, y apoya a sus tutores (familia, docentes y terapeutas) con alertas y estrategias sensoriales. Requisitos en [REQUISITOS.md](REQUISITOS.md) y plan en [PLAN.md](PLAN.md).

> Estado: **Fase 1 en curso** (captura de sesiones con el EmotiBit real). Ver [PLAN.md](PLAN.md).

## Estructura del repositorio

```
kuusense/
├── apps/
│   ├── mobile/            App Flutter (iOS/Android) para tutores y modo niño
│   └── web/               Plataforma web Flutter para investigadores y admin
├── packages/
│   ├── emotibit/          Comunicación con el EmotiBit, en Dart puro (sin Flutter)
│   ├── kuusense_models/   Modelo de datos compartido (Dart puro)
│   └── kuusense_firebase/ Firebase, autenticación (AuthService) y repositorio de datos
├── shared/
│   ├── design/            Tokens de identidad visual (fuente de verdad) y CSS para la landing
│   └── kuusense_ui/       Tema, logo, assets y validaciones para las apps Flutter
├── tools/
│   ├── emotibit_cli/      Herramienta de terminal: scan, monitor, record, analyze, simulate
│   └── design_tokens/     Generador: tokens.json → Dart + CSS (`make tokens`)
├── firebase/              Reglas de seguridad, índices y sus tests
└── docs/                  Requisitos, plan, arquitectura y guías
```

Dependencias permitidas (de arriba hacia abajo, nunca al revés):

```
apps/mobile ──┬──▶ packages/kuusense_firebase ──▶ packages/kuusense_models
              ├──▶ packages/emotibit
              └──▶ shared/kuusense_ui
apps/web ─────┬──▶ packages/kuusense_firebase ──▶ packages/kuusense_models
              └──▶ shared/kuusense_ui
tools/emotibit_cli ▶ packages/emotibit
```

- **`packages/emotibit` no sabe nada de Firebase, de la app ni de Flutter.** Solo habla con el dispositivo. Por eso lo usan igual la app móvil, la herramienta de terminal y los tests, y sirve también en un computador de captura de laboratorio.
- **La web no depende de `emotibit`**: nunca habla directo con el dispositivo.
- **Identidad visual:** las apps no escriben colores ni tamaños a mano. Todo sale de `shared/design/tokens.json` (ver [shared/README.md](../shared/README.md)).
- **Autenticación:** las pantallas dependen de la interfaz `AuthService`. Integrar Firebase Auth es implementar esa interfaz. Hoy las apps usan `NotConfiguredAuthService`, que responde "aún no disponible".
- **Organización de las apps:** cada funcionalidad vive en `lib/features/<nombre>/` (por ejemplo `features/auth/`).
- Todo el acceso a Firestore y Storage pasa por `kuusense_firebase`. Si algún día se cambia de nube, el cambio queda en un solo lugar.

Es un *pub workspace* de Dart: `flutter pub get` en la raíz instala todo.

## Flujo de datos (objetivo)

```
EmotiBit ──WiFi (UDP/TCP)──▶ App móvil del tutor ──▶ Firebase ──▶ Plataforma web
                                   │                    │
                                   │                    └─▶ Servicio de IA (Fase 3) ──▶ push de alerta
                                   └─ grabación local (sin pérdida si se cae internet)
```

## Paquete `emotibit`

| Archivo | Qué hace |
|---|---|
| `packet.dart` | Lee y escribe paquetes EmotiBit |
| `type_tags.dart` | Catálogo de tipos de paquete (EA = EDA, PG = PPG verde, etc.) |
| `host.dart` | Descubre, conecta, mantiene viva la conexión y sincroniza el reloj. Tiene modo diagnóstico |
| `recorder.dart` | Graba sesiones en disco (raw, sync, events) |
| `stats.dart` | Frecuencia real, rangos y paquetes perdidos por señal |
| `simulator.dart` | EmotiBit simulado para desarrollar y testear sin hardware |

### Protocolo (resumen)

Verificado contra el firmware oficial (`EmotiBit_FeatherWing/EmotiBitWiFi.cpp`, `EmotiBit_XPlat_Utils/EmotiBitPacket.cpp`):

- **Paquete:** `timestamp,packetNumber,dataLength,typeTag,protocolVersion,dataReliability[,payload…]\n`. Un datagrama puede traer varios paquetes.
- **Descubrimiento:** el host envía `HE` al puerto UDP **3131** y el dispositivo responde `HH` con `DP,<port>,DI,<deviceId>`.
- **Conexión:** el host abre un servidor TCP (control) y un socket UDP (datos), y envía `EC` con `CP,<cp>,DP,<dp>`. El dispositivo se conecta por TCP y responde `PO`.
- **Keepalive:** `PN` con `DP,<dp>` al menos cada 10 s; nosotros lo enviamos cada 2 s.
- **Sincronización de reloj:** cada ~5 s el dispositivo envía `RD` y el host responde `TL`, `TU` y `AK`.

**Verificado con el hardware real** (25-11-2026, EmotiBit `MD-V7-0000829`, HW V07a, firmware 1.14.0, una sesión de 5 min en reposo; detalle en [EMOTIBIT_PRIMEROS_PASOS.md](EMOTIBIT_PRIMEROS_PASOS.md)):

- Nuestro descubrimiento, conexión, keepalive y sincronización funcionan sin cambios.
- **ID:** formato `MD-V7-0000829`.
- **Tags que llegan:** `EA EL PG PI PR AX AY AZ GX GY GZ MX MY MZ T1 TH HR BI SA SR SF B% BV EM`, más `RD TL TU AK` de sincronización. **No llega `T0`**: la temperatura viene como `T1` y `TH` (termopila).
- **Frecuencias:** EDA 15 Hz, PPG e IMU 25 Hz, temperatura 7,5 Hz, HR y BI 1 Hz, batería cada ~5 s.
- **HR y BI** los calcula el propio EmotiBit. Hay valores aislados irreales (máx. 210,9 bpm), así que hay que filtrarlos.
- **Sincronización:** el dispositivo envía `RD` cada ~5,1 s. Los `TL` (hora local) y `TU` (hora UTC) quedan en el flujo con formato `2026-11-25_15-43-29-275851`, seguidos de un `AK`.
- **Numeración de paquetes:** no empieza en 0 al conectar y no siempre llega en orden. Los paquetes de control (`RD`, `TL`, `TU`, `AK`) se intercalan con números cercanos. Los `EM` y `RD` a veces llegan duplicados (misma línea dos veces).
- **Pérdida de paquetes:** 0,5 a 0,8 % cerca del router.
- **EDA sin contacto:** si los electrodos no tocan la piel, `EA` queda fija en ~0,0302 µS (`EL` saturado). En la parte superior del brazo no hubo contacto; en la yema del dedo índice sí.

**No verificado todavía:** la estabilidad en sesiones de 15 minutos, la pérdida de paquetes con movimiento o lejos del router, la respuesta de la EDA a un estímulo y que el `raw.csv` abra en el DataParser oficial.

### Formato de una sesión grabada
- `raw.csv`: líneas tal cual las envía el EmotiBit, compatibles con el **EmotiBit DataParser** oficial.
- `sync.csv`: pares `host_epoch_ms,device_ms` (~1/s) para pasar el reloj del dispositivo (ms desde el encendido) a hora real.
- `events.csv`: eventos marcados durante la sesión, con la hora del teléfono y la del dispositivo. Guarda el id de la conducta (`crisisStart`, `note:texto`); un error se corrige con una línea `undo:<id>`, sin borrar. Los cortes de conexión quedan como `gap_start` y `gap_end`.
- `signals.csv`: resumen de un valor por segundo (frecuencia cardíaca, EDA, temperatura de la piel, intensidad de movimiento y batería) para los gráficos de la web. Lo genera el grabador al terminar, o `emotibit preview <carpeta>` para una grabación existente. Las cifras de toda la sesión (rango de cada señal, respuestas de EDA, pérdida de paquetes y batería) van en el campo `stats` de la sesión en Firestore.
- `session.json` (solo en el teléfono, no se sube): metadatos para la cola de subida y para recuperar la sesión si la app se cierra a mitad de la grabación.
- El documento de la sesión guarda `endReason` (`stopped`: la detuvo el tutor; `deviceLost`: el EmotiBit no volvió; `appClosed`: la app se cerró y la sesión se recuperó al abrirla) y `gaps` (tramos sin datos, `{fromMs, toMs}` en hora del teléfono). Si `endReason` no es `stopped`, la sesión se muestra como incompleta.
- El documento de la sesión en Firestore guarda además el contexto (`context`: lugar, actividad, tipos de tutor presentes) y la lista de eventos (`events`), para verlos en vivo y filtrar el dataset.

## Firebase

- **Auth:** correo y contraseña. Sin acceso anónimo.
- **Firestore:** solo metadatos y valores resumidos. **Nunca** se guardan muestras de alta frecuencia.
- **Storage:** archivos de las sesiones en `children/{childId}/sessions/{sessionId}/` (`raw.csv`, `sync.csv`, `events.csv`, `signals.csv`). CORS de solo lectura (GET) para la web publicada y `localhost:5050`, definido en `firebase/storage-cors.json` y aplicado con `gcloud storage buckets update --cors-file`.
- **Permiso necesario en cada proyecto real:** las reglas de Storage consultan Firestore (¿es staff?, ¿quién grabó la sesión?), así que el agente de servicio de Storage (`service-<número>@gcp-sa-firebasestorage.iam.gserviceaccount.com`) necesita el rol `roles/firebaserules.firestoreServiceAgent`. Publicando las reglas desde la terminal no se otorga solo; sin él, nadie puede leer ni subir archivos de sesiones. Ya está otorgado en `kuusense-test`.
- **Importar una grabación de la terminal:** `make import-session DIR=recordings/<fecha> CHILD=<childId>` la sube a `kuusense-test` como si la hubiera subido la app.
- **Reglas** con tests automáticos en `firebase/test/`.
- Desarrollo local con emuladores (proyecto `demo-kuusense`), sin un proyecto real.

### Modelo de datos (Fase 0)

Definido en `packages/kuusense_models/lib/src/models.dart`.

| Ruta | Contenido | Quién lo ve |
|---|---|---|
| `tutors/{uid}` | Nombre visible, tipo (familiar, docente o terapeuta), correo, si está activo y la ruta de su foto de perfil opcional (en Storage, `tutors/{uid}/photo-<ms>.jpg`). La contraseña queda solo en Auth | El propio tutor y el admin |
| `tutors/{uid}/public/card` | Tarjeta pública del tutor: nombre, tipo y foto (nunca el correo). Se actualiza junto con el perfil | Cualquier tutor activo y el admin, solo pidiéndola por id (no se listan). En la práctica, los tutores que comparten un NNA |
| `staff/{uid}` | Rol (investigador o admin), nombre, correo, si está activo y fecha de creación. Los investigadores los crea, edita y desactiva el admin desde la web (mantenedor de Investigadores). Los admins se crean solo con herramientas de administración (`make staff`) | El propio usuario y el admin |
| `children/{id}` | **Parte de investigación del NNA:** código seudónimo (`N-4F7Q`), año de nacimiento, cuadrante de Dunn, responsable, tutores vinculados y fecha de confirmación del consentimiento | Tutores vinculados y staff |
| `children/{id}/private/profile` | **Parte privada:** apodo, avatar predefinido (sin fotos) y fecha de nacimiento completa (`AAAA-MM-DD`, opcional en registros antiguos). La parte de investigación solo tiene el año | Tutores vinculados y admin (nunca investigadores) |
| `children/{id}/sessions/{id}` | Metadatos de cada grabación | Tutores vinculados y staff |
| `invites/{código}` | Código de invitación de 6 caracteres, válido por 48 h y de un solo uso | Se consulta por código exacto, nunca se lista |

**Sesiones de inicio:** en la app móvil la sesión del tutor se mantiene hasta que cierra sesión. En la plataforma web la sesión **nunca persiste**: dura mientras la pestaña está abierta (sobrevive a recargar la página) y termina al cerrar la pestaña o el navegador.

**Roles:** administrador, investigador y tutor. Una misma cuenta puede tener más de uno (por ejemplo, admin y tutor).

**Permisos principales:**
- **Solo el admin crea tutores**, desde la plataforma web (sección Tutores). La app no tiene registro. La cuenta se crea con una contraseña aleatoria y el tutor recibe un correo para elegir la suya. Se hace con una segunda instancia de Firebase en el navegador, sin Cloud Functions. Si el correo ya tiene cuenta (por ejemplo, alguien del staff), se habilita con `make tutor`.
- El admin edita y **desactiva** tutores (no los borra). Un tutor desactivado conserva sus vínculos, pero las reglas le niegan todo acceso a NNA, sesiones e invitaciones.
- **El NNA lo registra un tutor (app) o el admin (web, sección NNA) eligiendo el tutor responsable.** Ambos usan el mismo formulario compartido (`KuuChildForm` en `shared/kuusense_ui`), con confirmación de consentimiento.
- El admin edita al NNA, elige qué tutores lo acompañan y quién es el responsable, y puede eliminarlo. Lee el apodo, el avatar y la fecha de nacimiento; los investigadores nunca.
- Los tutores vinculados editan el perfil, invitan a otros tutores y graban sesiones. Por ahora, todos los tipos de tutor tienen los mismos permisos.
- Solo el responsable elimina al NNA o desvincula a otros. Cualquier tutor puede desvincularse.
- Para unirse, un tutor se agrega a sí mismo y borra la invitación en la misma operación. Así la invitación no se reutiliza, sin necesidad de Cloud Functions.
- Los investigadores leen la parte de investigación y todas las sesiones, pero nunca la parte privada ni los datos de los tutores. No modifican nada.
- La foto de perfil del tutor (JPEG o PNG, menos de 2 MB, unos 512 px) la sube, cambia o quita el propio tutor. La ven él, el admin y los otros tutores activos (los que comparten un NNA la encuentran en su tarjeta pública). Nunca los investigadores. Los NNA no tienen fotos, solo avatares predefinidos.
- Solo el teléfono que grabó una sesión sube sus archivos. Los datos crudos solo los descarga el staff.
- Las sesiones no se borran desde las apps. La eliminación queda sujeta a la política de retención, que se implementará con herramientas de administración.

## Limitaciones conocidas
1. **iOS:** buscar dispositivos por broadcast requiere un permiso de Apple (multicast). Mientras tanto se conecta por IP.
2. **Grabación robusta (app móvil):**
   - **Cortes:** 5 s sin datos del EmotiBit cuentan como un corte. La grabación sigue y la app busca el mismo dispositivo cada 3 s, primero en su última IP y después por broadcast, durante un máximo de 5 minutos.
   - **Segundo plano:** en Android, un servicio en primer plano con notificación mantiene la grabación con la pantalla apagada. En iPhone, Apple no lo permite: la pantalla queda encendida y se puede oscurecer desde la app.
   - **Subida:** una cola en disco sube las sesiones pendientes al abrir la app, cada 2 minutos y al terminar cada grabación.
   - **Pendiente de probar con el hardware real.**
3. Borrar por completo la cuenta de un tutor (Auth) requiere herramientas de administración; desde la web solo se desactiva. El texto del correo de acceso es la plantilla de "restablecer contraseña" de Firebase (se puede personalizar en la consola).
4. Al eliminar un NNA, sus sesiones quedan guardadas de forma seudónima hasta que exista la herramienta de retención.
