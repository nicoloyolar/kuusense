# KúuSense — Arquitectura

KúuSense anticipa episodios de desregulación emocional en NNA con TEA usando las señales fisiológicas de un **EmotiBit**, y apoya a sus tutores (familia, docentes y terapeutas) con alertas y estrategias sensoriales. Requisitos en [REQUISITOS.md](REQUISITOS.md) y plan en [PLAN.md](PLAN.md).

> Estado: **Fase 0 en curso.** Listos: la estructura del repo, la comunicación con el EmotiBit, la identidad visual compartida (provisoria) y las pantallas de login de ambas apps (sin conectar a Firebase Auth). Pendiente: el modelo de datos de tutores y NNA y el resto de las pantallas. En `apps/*/lib/screens/` y `apps/mobile/lib/app_controller.dart` queda código del esqueleto inicial, ya desconectado, que se reemplazará.

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

**No verificado todavía** (se valida con el hardware real, ver [EMOTIBIT_PRIMEROS_PASOS.md](EMOTIBIT_PRIMEROS_PASOS.md)): el formato de `TL`/`TU`, las frecuencias reales, los tags que realmente llegan, el formato del ID y la numeración de paquetes.

### Formato de una sesión grabada
- `raw.csv`: líneas tal cual las envía el EmotiBit, compatibles con el **EmotiBit DataParser** oficial.
- `sync.csv`: pares `host_epoch_ms,device_ms` (~1/s) para pasar el reloj del dispositivo (ms desde el encendido) a hora real.
- `events.csv`: eventos marcados durante la sesión, con la hora del teléfono y la del dispositivo. Guarda el id de la conducta (`crisisStart`, `note:texto`); un error se corrige con una línea `undo:<id>`, sin borrar.
- El documento de la sesión en Firestore guarda además el contexto (`context`: lugar, actividad, tipos de tutor presentes) y la lista de eventos (`events`), para verlos en vivo y filtrar el dataset.

## Firebase

- **Auth:** correo y contraseña. Sin acceso anónimo.
- **Firestore:** solo metadatos y valores resumidos. **Nunca** se guardan muestras de alta frecuencia.
- **Storage:** archivos de las sesiones en `children/{childId}/sessions/{sessionId}/` (`raw.csv`, `sync.csv`, `events.csv`).
- **Reglas** con tests automáticos en `firebase/test/`.
- Desarrollo local con emuladores (proyecto `demo-kuusense`), sin un proyecto real.

### Modelo de datos (Fase 0)

Definido en `packages/kuusense_models/lib/src/models.dart`.

| Ruta | Contenido | Quién lo ve |
|---|---|---|
| `tutors/{uid}` | Nombre visible y tipo (familiar, docente o terapeuta). El correo queda solo en Auth | El propio tutor y el staff |
| `staff/{uid}` | Rol: investigador o admin. Se crea solo con herramientas de administración | El propio usuario |
| `children/{id}` | **Parte de investigación del NNA:** código seudónimo (`N-4F7Q`), año de nacimiento, cuadrante de Dunn, responsable, tutores vinculados y fecha de confirmación del consentimiento | Tutores vinculados y staff |
| `children/{id}/private/profile` | **Parte privada:** apodo y avatar predefinido (sin fotos) | Solo los tutores vinculados |
| `children/{id}/sessions/{id}` | Metadatos de cada grabación | Tutores vinculados y staff |
| `invites/{código}` | Código de invitación de 6 caracteres, válido por 48 h y de un solo uso | Se consulta por código exacto, nunca se lista |

**Permisos principales:**
- Cualquier tutor registra un NNA y queda como responsable. Debe confirmar el consentimiento del cuidador.
- Los tutores vinculados editan el perfil, invitan a otros tutores y graban sesiones. Por ahora, todos los tipos de tutor tienen los mismos permisos.
- Solo el responsable elimina al NNA o desvincula a otros. Cualquier tutor puede desvincularse.
- Para unirse, un tutor se agrega a sí mismo y borra la invitación en la misma operación. Así la invitación no se reutiliza, sin necesidad de Cloud Functions.
- El staff lee la parte de investigación y todas las sesiones, pero nunca la parte privada. Tampoco modifica datos de los NNA.
- Solo el teléfono que grabó una sesión sube sus archivos. Los datos crudos solo los descarga el staff.
- Las sesiones no se borran desde las apps. La eliminación queda sujeta a la política de retención, que se implementará con herramientas de administración.

## Limitaciones conocidas
1. **iOS:** buscar dispositivos por broadcast requiere un permiso de Apple (multicast). Mientras tanto se conecta por IP.
2. La reconexión automática y la cola de subida persistente están planificadas para la Fase 1.
3. Las pantallas de tutor y NNA, y la web de staff, todavía están por construir (Fase 0).
4. Al eliminar un NNA, sus sesiones quedan guardadas de forma seudónima hasta que exista la herramienta de retención.
