# KúuSense — Plan de trabajo

> Versión 0.1 · 24-11-2026 · **Borrador para aprobación**
> Basado en [REQUISITOS.md](REQUISITOS.md). Cada fase se aprueba antes de empezar y se cierra con una revisión de lo construido.

## Principios
- **Incremental:** cada fase deja algo que funciona y se puede probar. Nada queda a medias para "después".
- **Primero lo que el proyecto CORFO necesita antes:** el dataset (meses 1–6) va antes que las alertas (meses 6–9) y que la app final (meses 9–12).
- **Desarrollo sin hardware ni nube real:** el simulador de EmotiBit y los emuladores de Firebase permiten avanzar mientras tanto. El hardware real entra apenas esté disponible.
- **Cada fase se verifica:** tests automáticos más una revisión contigo en pantalla.

## Qué se reutiliza del esqueleto actual

| Pieza | Destino |
|---|---|
| Módulo de protocolo EmotiBit, simulador y grabador | **Se mantiene.** Las frecuencias del simulador coinciden con el concepto tecnológico |
| Estructura del monorepo, configuración de Firebase y emuladores | **Se mantiene** |
| Repositorio de datos compartido | **Se mantiene** y se adapta al nuevo modelo |
| Modelo "estudio / participante / código de estudio" | **Se reemplaza** por tutores y NNA |
| Pantallas de la app y la web | **Se rehacen** según el flujo de uso |
| Reglas de seguridad y sus tests | **Se reescriben** para el nuevo modelo (los tests se mantienen como práctica) |

---

## Fase 0: Base reorientada a KúuSense
**Objetivo:** que la base existente refleje el producto real.

- Modelo de datos: tutores, NNA y el vínculo tutor–NNA (de muchos a muchos). La invitación de tutores se hace con un mecanismo simple y fácil de cambiar después, por ejemplo un código.
- App móvil: splash, bienvenida, registro e inicio de sesión del tutor, perfil del tutor, registro del NNA y selección del NNA.
- App móvil: conectar el EmotiBit (simulado) y ver sus señales en vivo para el NNA seleccionado.
- Web: inicio de sesión de investigador o admin y listado de NNA y sesiones.
- Reglas de seguridad con tests: un tutor solo ve a los NNA vinculados.
- Actualizar ARCHITECTURE.md, CLAUDE.md y README. Primer commit en git.
- Identidad visual básica (colores y logo de KúuSense) si la clienta comparte los recursos.

**Listo cuando:** dos tutores con cuentas distintas ven al mismo NNA, uno de ellos conecta el EmotiBit simulado y ve las señales, y los tests pasan.

## Fase 1: Captura de sesiones para el dataset
**Objetivo:** que el equipo pueda grabar sesiones reales de buena calidad (meta de la Fase 1 CORFO).

- Validar el protocolo con un **EmotiBit real** y ajustar lo necesario.
- Grabación robusta: reconexión automática, grabación con la pantalla apagada y cola de subida persistente.
- Marcadores de eventos y conductas durante la sesión (etiquetas para la IA).
- Metadatos de la sesión (lugar, actividad, tutor presente) e indicador de calidad de señal por canal.
- Web: listado de sesiones, calidad de señal, descarga y exportación del dataset para el equipo de IA.
- *Depende de las preguntas 2, 7 y 9 de REQUISITOS.md.*

**Listo cuando:** una sesión con un EmotiBit real queda en la nube completa, con eventos, y se abre con el DataParser oficial de EmotiBit.

## Fase 2: Modo Niño y estrategias
**Objetivo:** la parte de la app que usa el NNA y el ciclo de estrategias.

- Cambio entre modo Tutor y modo Niño, con bloqueo.
- Check-in emocional, tarjetas de estrategias, "muéstrame otra", "estoy mejor", check-out y reforzador.
- Botón de ayuda con notificación push al tutor.
- Biblioteca de estrategias por cuadrante de Dunn y perfil sensorial del NNA, configurable por el tutor.
- *Depende de la pregunta 10 (catálogo de estrategias).*

**Listo cuando:** el NNA hace el ciclo completo (check-in, estrategia y check-out) y el tutor recibe la notificación.

## Fase 3: Monitoreo en tiempo real y alertas
**Objetivo:** el semáforo del NNA y la alerta de pre-crisis (Fase 2 CORFO).

- Envío continuo de señales (o de indicadores ya calculados) desde el celular a la nube.
- Servicio de inferencia en Python con el modelo intercambiable. Parte con un modelo de prueba o con reglas simples.
- Semáforo en la app del tutor y **notificación push de pre-crisis** con la estrategia sugerida.
- Funciona con conectividad intermitente.
- *Depende de las preguntas 4 y 5 (modelo y equipo de IA).*

**Listo cuando:** con el simulador provocando una "crisis", el tutor recibe la alerta en menos de 2 s.

## Fase 4: Historial, reportes y dashboard profesional
- Calendario, episodios por fecha y estadísticas de estrategias.
- Reportes manuales del tutor.
- Dashboard profesional (métricas de sesión, evolución).
- Web: visor de señales con eventos y herramienta de etiquetado ciego (κ).

## Fase 5: Módulos adicionales (según prioridades de la clienta)
- Chat con KúuSense IA (tutor y niño).
- Avatar con IA, tablero CAA (pictogramas) y respuestas por voz.
- Autocuidado del tutor y mensajería entre familia y terapeuta.
- Inicio de sesión con huella o Face ID.

## Transversal (en paralelo, según disponibilidad)
- **Proyecto Firebase real** (desarrollo y producción) antes de usar datos reales.
- **Revisión legal y del Comité Ético** antes de grabar a NNA reales.
- **Distribución de pruebas:** TestFlight (iOS) y Play Console (Android) desde la Fase 1.

---

## Alineación con las fases CORFO

| CORFO | Meses | Necesita del software | Fases del plan |
|---|---|---|---|
| Fase 1 (TRL 3→4) | 1–6 | Captura de un dataset de calidad | 0, 1 |
| Fase 2 (TRL 4) | 6–9 | App beta con alertas, estrategias Dunn y dashboard | 2, 3, parte de 4 |
| Fase 3 (TRL 5) | 9–12 | App final en escuelas y hogares | 4, 5 y robustez |

El ajuste fino depende de en qué mes del proyecto estamos (pregunta 6).
