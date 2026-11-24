# KúuSense — Requisitos consolidados

> Versión 0.1 · 24-11-2026 · **Borrador para revisar con la clienta**
> Fuentes: *Concepto Tecnológico KúuSense™* (EDAM Espacio Kúu SpA, jun-2026, confidencial) y *Flujo de uso – Esquema Prototipo*. Incluye las decisiones tomadas con el equipo de desarrollo el 24-11-2026.
> Las fuentes son confidenciales: no compartir este documento fuera del equipo.

## 1. Qué es el producto

KúuSense es un sistema que **anticipa episodios de desregulación emocional en niños, niñas y adolescentes (NNA) con TEA** y **apoya a quienes los acompañan**: familia, docentes y terapeutas.

1. Un wearable **EmotiBit** capta señales fisiológicas (EDA, PPG/frecuencia cardíaca, movimiento, temperatura).
2. Un **modelo de IA** analiza las señales y estima si el NNA está *Estable*, en *Alerta* o en *Pre-crisis*, idealmente 1 a 3 minutos antes de que la crisis sea visible.
3. La **app móvil** avisa al tutor y sugiere **estrategias sensoriales** según el perfil del NNA (modelo de Dunn). El NNA también tiene su propio modo para expresar cómo se siente y recibir estrategias.

Contexto: proyecto CORFO Semilla Inicia de 12 meses, para pasar de TRL 3 a TRL 5, con pilotos en salas terapéuticas, escuelas PIE y hogares de la Región del Biobío.

## 2. Usuarios

| Rol | Quién es | Dónde trabaja |
|---|---|---|
| **Tutor** | Familiar, docente o terapeuta | App móvil, con su propia cuenta |
| **Usuario (NNA)** | Niño, niña o adolescente con TEA, de 5 a 14 años | App móvil en "modo niño" (interfaz simplificada) |
| **Investigador** | Equipo clínico y de IA del proyecto | Plataforma web |
| **Admin** | Equipo KúuSense | Plataforma web |

**Decidido:** cada tutor usa la app en su propio teléfono y con su propia cuenta. **Un mismo NNA puede estar vinculado a varios tutores** (por ejemplo, mamá, profesora y terapeuta).
**Abierto:** quién registra al NNA, cómo se invita a otro tutor y qué permisos tiene cada tipo de tutor.

## 3. Requisitos funcionales

Prioridad: **P1** = necesario para el objetivo del proyecto · **P2** = importante · **P3** = posterior, como módulo separado.

### 3.1 Cuenta y perfiles
| ID | Requisito | Prioridad |
|---|---|---|
| CU-1 | Crear cuenta e iniciar sesión con correo y contraseña; recuperar la contraseña | P1 |
| CU-2 | Perfil del tutor con su tipo (familiar, docente, terapeuta) | P1 |
| CU-3 | Registrar un NNA con un perfil seudónimo: nombre visible o apodo, avatar, edad y perfil sensorial | P1 |
| CU-4 | Vincular varios tutores a un mismo NNA | P1 |
| CU-5 | Cambiar entre modo Tutor y modo Niño en el mismo teléfono, con **bloqueo para volver al modo Tutor** (PIN o huella) | P2 |
| CU-6 | Iniciar sesión con huella o Face ID | P3 |
| CU-7 | Avatar del NNA generado con IA a partir de su foto | P3 |

### 3.2 EmotiBit y monitoreo
| ID | Requisito | Prioridad |
|---|---|---|
| EB-1 | Buscar y conectar un EmotiBit por WiFi desde la app | P1 |
| EB-2 | Ver el estado del dispositivo (conectado, batería, calidad de señal) | P1 |
| EB-3 | Grabar sesiones completas con todas las señales en el formato nativo de EmotiBit, que siguen grabándose aunque se corte la conexión con la nube | P1 |
| EB-4 | Durante la sesión, marcar eventos y conductas observadas, que servirán de etiquetas para entrenar la IA | P1 |
| EB-5 | Subir las sesiones a la nube con reintentos, sin perder datos | P1 |
| EB-6 | Monitoreo en tiempo real: estado del NNA (verde, amarillo o rojo) actualizado cada ~1 s | P2 |
| EB-7 | **Alerta de pre-crisis como notificación push** en la app del tutor, con la estrategia sugerida | P2 |
| EB-8 | Captura sincronizada con la cámara Intel RealSense (video) | Abierto: se haría en un computador, no en la app |

### 3.3 Modo Niño
| ID | Requisito | Prioridad |
|---|---|---|
| NI-1 | Interfaz simplificada: letra grande, colores, sonido que se puede silenciar | P2 |
| NI-2 | Check-in emocional "¿Cómo estás hoy?": 5 caritas, deslizador y opción "no sé" | P2 |
| NI-3 | Responder por voz, texto o pictogramas | P3 |
| NI-4 | Tarjetas con 2 o 3 estrategias según la emoción y el perfil sensorial, más "muéstrame otra" | P2 |
| NI-5 | Botón "estoy mejor" y check-out "¿Cómo estás ahora?" con reforzador | P2 |
| NI-6 | Botón de ayuda con acciones rápidas configurables por el tutor, que notifica al tutor | P2 |
| NI-7 | Notificar al tutor el resultado del check-in | P2 |
| NI-8 | Tablero de comunicación (CAA) | P3: el concepto tecnológico lo deja fuera de la v1.0 |

### 3.4 Modo Tutor
| ID | Requisito | Prioridad |
|---|---|---|
| TU-1 | Dashboard con acceso a monitoreo, estrategias, historial y configuración | P1 |
| TU-2 | Biblioteca de estrategias sensoriales organizada por cuadrante de Dunn | P2 |
| TU-3 | Configurar el perfil sensorial (cuadrante de Dunn) y las preferencias del NNA | P2 |
| TU-4 | Historial: calendario, episodios por fecha, estadísticas de estrategias usadas | P2 |
| TU-5 | Ingresar reportes manuales (episodios en casa o en el colegio) | P2 |
| TU-6 | Notificaciones (alertas, check-ins, botón de ayuda) | P2 |
| TU-7 | Sección de autocuidado para el tutor | P3 |
| TU-8 | Mensajería entre familia y terapeuta | P3 |
| TU-9 | Dashboard profesional: métricas de sesión, calidad de señal y evolución semanal o mensual | P2 |

### 3.5 Inteligencia artificial
| ID | Requisito | Prioridad |
|---|---|---|
| IA-1 | Exportar el dataset (señales, etiquetas y perfil seudónimo) en un formato útil para el equipo de IA | P1 |
| IA-2 | Servicio en la nube que reciba las señales en vivo y devuelva el estado (Estable, Alerta o Pre-crisis) | P2 |
| IA-3 | Integrar el modelo que entregue el equipo de IA (Gradient Boosting y luego CNN-LSTM, en Python) | P2 |
| IA-4 | Chat con "KúuSense IA" para el tutor y para el niño | P3: **no integrado por ahora** |

### 3.6 Plataforma web
| ID | Requisito | Prioridad |
|---|---|---|
| WE-1 | Acceso para investigadores y admin | P1 |
| WE-2 | Ver sesiones, su calidad de señal y descargar los datos | P1 |
| WE-3 | Visualizar las señales de una sesión junto con sus eventos | P2 |
| WE-4 | Herramienta de etiquetado ciego por 2 profesionales (Estable, Alerta, Pre-crisis), con medición del acuerdo (κ) | P2 |
| WE-5 | Administrar usuarios, tutores, NNA y estrategias | P2 |

## 4. Señales del EmotiBit

| Señal | Frecuencia | Uso |
|---|---|---|
| EDA (electrodérmica) | 15 Hz | Activación simpática |
| PPG infrarrojo, rojo y verde → FC / HRV | 25 Hz (100 Hz con firmware alternativo) | Frecuencia cardíaca, RMSSD, SDNN, LF/HF |
| IMU de 9 ejes | 25 Hz | Movimiento, stimming |
| Temperatura (termopila) y humedad | 7,5 Hz | Balance autonómico |

Meta de calidad: al menos 90 % de datos válidos por sesión en la Fase 1 CORFO y al menos 95 % después. El EmotiBit también graba en su microSD como respaldo.

## 5. Requisitos no funcionales

- **Privacidad:** los datos son de salud de menores, por lo que se tratan como datos sensibles. Hay que seudonimizar, minimizar los datos guardados, tener una política de retención y eliminación, y aplicar control de acceso por rol. Marco legal: Ley 19.628, Ley 21.096 y la nueva Ley 21.719 de datos personales (**validar con un abogado**), además de la Ley TEA 21.545.
- **Ética:** todo protocolo con NNA requiere aprobación del Comité Ético de la USS, consentimiento de los cuidadores y asentimiento del NNA. El retiro del wearable debe ser inmediato si hay molestia.
- **Seguridad:** cifrado en tránsito y en reposo, registro de accesos (auditoría) y principio de mínimo privilegio.
- **Conectividad intermitente:** la app no pierde datos si se cae internet en el colegio o en la casa.
- **Latencia:** el objetivo de la alerta en tiempo real es menos de 2 s.
- **Plataformas:** iOS y Android.
- **Idioma:** español de Chile.
- **Accesibilidad:** modo claro y oscuro, sonido que se puede silenciar, opciones de accesibilidad.

## 6. Decisiones tomadas

| Fecha | Decisión |
|---|---|
| 24-11-2026 | Stack: **Flutter** (app y web) + **Firebase**. Una eventual expansión a otra nube queda abierta. |
| 24-11-2026 | El EmotiBit se conecta **directamente al celular por WiFi**, y el celular envía los datos a la nube. Falta validarlo con la clienta. |
| 24-11-2026 | Cada tutor tiene su propia app y cuenta, y varios tutores pueden ver al mismo NNA. |
| 24-11-2026 | La alerta parte como notificación push y se escala después. |
| 24-11-2026 | El chat con IA, el avatar con IA y el tablero CAA quedan para más adelante, como módulos separados. |
| 24-11-2026 | No hay una demo programada. Se construye de forma incremental. |
| 24-11-2026 | El nombre "SensoRegula" no se considera (MVP anterior). |
| 24-11-2026 | Modelo de datos: el NNA se guarda en dos partes, una seudónima para investigación y una privada (apodo y avatar) solo para sus tutores. Se guarda el año de nacimiento, no la fecha completa, y no se guardan fotos. |
| 24-11-2026 | Cualquier tutor registra un NNA confirmando el consentimiento del cuidador. Otros tutores se vinculan con un código de 6 caracteres, válido por 48 h y de un solo uso. Por ahora, todos los tipos de tutor tienen los mismos permisos (pendiente pregunta 3). |

## 7. Preguntas abiertas para la clienta

1. **AWS:** el concepto tecnológico lista "App desplegada en AWS" y "Auditoría despliegue AWS" como entregables (pág. 21). ¿Es un compromiso formal con CORFO o es flexible?
2. **Captura en laboratorio:** cuando se use la cámara RealSense (que se conecta a un computador por USB), ¿la sesión se captura en un PC con LSL o con el celular?
3. **Registro del NNA y vínculos:** ¿quién crea el perfil del NNA, cómo se invita a otro tutor y qué puede ver cada uno?
4. **Código y datos existentes (TRL 3):** ¿podemos acceder al pipeline de Gradient Boosting y al dataset preliminar?
5. **Equipo de IA:** ¿quién construye y entrena el modelo (KúuSense, USS, UdeC)? ¿En qué formato lo entregan?
6. **Calendario CORFO:** ¿en qué mes del proyecto estamos y qué entregable de software vence primero?
7. **Hardware:** ¿cuántos EmotiBit hay disponibles y cuándo podemos probar con uno real? ¿Se usará el firmware de PPG a 100 Hz?
8. **Datos personales:** el flujo de uso habla de "todos los datos personales" y de la foto del NNA. El concepto tecnológico promete seudonimización. ¿Qué datos personales son realmente necesarios?
9. **Etiquetado:** ¿quiénes etiquetan los episodios y desde dónde (en vivo durante la sesión, o después con el video)?
10. **Estrategias:** ¿existe un catálogo de estrategias por cuadrante de Dunn y emoción (textos e imágenes)? ¿Quién lo mantiene?

## 8. Inconsistencias detectadas en el concepto tecnológico

- Meta de AUROC para TRL 5: ≥ 0,85 (tabla de métricas) contra ≥ 0,82 (portada y síntesis).
- Tamaño de la cohorte: "≥50 NNA" en la Fase 1, "≥30 adicionales (total ≥50)" en la Fase 2 y "≥80 NNA" en el entregable de la Fase 2.
- Se compran 2 EmotiBit para 50 o más NNA. Es viable con sesiones en secuencia, pero condiciona el calendario.

## 9. Riesgos principales

| Riesgo | Mitigación |
|---|---|
| El protocolo del EmotiBit no está probado con hardware real (se usó un simulador) | Probar con un EmotiBit real lo antes posible (Fase 1 del plan) |
| iOS limita la búsqueda de dispositivos por broadcast | Conexión por IP como alternativa; pedir el permiso de multicast a Apple |
| Si no hay modelo de IA a tiempo, no hay alertas reales | La app y el servicio de alertas aceptan un modelo intercambiable; mientras tanto se usan reglas simples o un modelo de prueba |
| Datos sensibles de menores | Seudonimización desde el diseño; revisión legal y del Comité Ético antes de usar datos reales |
| Firebase frente a una eventual exigencia de AWS | Todo el acceso a datos pasa por una sola capa (repositorio), para poder migrar |
