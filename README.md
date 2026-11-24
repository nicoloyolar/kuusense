# KúuSense

App y plataforma para anticipar episodios de desregulación emocional en NNA con TEA a partir de las señales fisiológicas de un EmotiBit.

| Documento | Contenido |
|---|---|
| [docs/REQUISITOS.md](docs/REQUISITOS.md) | Qué debe hacer el sistema, decisiones y preguntas abiertas |
| [docs/PLAN.md](docs/PLAN.md) | Plan por fases |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Estructura del repo y diseño técnico |
| [docs/EMOTIBIT_PRIMEROS_PASOS.md](docs/EMOTIBIT_PRIMEROS_PASOS.md) | Cómo conectar y analizar el EmotiBit real |

## Estructura

```
apps/mobile             App móvil (tutor y modo niño)
apps/web                Plataforma web (investigadores y admin)
packages/emotibit       Comunicación con el EmotiBit
packages/kuusense_*     Modelo de datos, autenticación y acceso a Firebase
shared/                 Identidad visual compartida (colores, fuentes, logos)
tools/                  Herramienta del EmotiBit y generador de tokens de diseño
firebase/               Reglas de seguridad y tests
```

## Requisitos
Flutter 3.27 o superior, Node 20 o superior, Firebase CLI y Java 21 (`brew install openjdk@21`).

```bash
make setup     # primera vez
make help      # lista de comandos
```

## EmotiBit desde el computador
```bash
make scan      # buscar EmotiBits en la red
make monitor   # ver en vivo qué envía
make record    # grabar una sesión en recordings/
make simulator # EmotiBit simulado (si no tienes el dispositivo)
```
Paso a paso en [docs/EMOTIBIT_PRIMEROS_PASOS.md](docs/EMOTIBIT_PRIMEROS_PASOS.md).

## Apps en local (sin proyecto Firebase real)
```bash
make emulators   # Firebase local; panel en http://localhost:4000
make simulator   # EmotiBit simulado
make web         # plataforma web
make mobile      # app móvil
```

## Tests
```bash
make test
make analyze
```
