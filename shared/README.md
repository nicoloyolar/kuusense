# shared/ — Identidad visual de KúuSense

Un solo lugar para la identidad del sistema (colores, tipografías, logos, imágenes). Lo usan la **app móvil**, la **plataforma web** y la futura **landing page**.

> Los valores actuales son **provisorios**: están tomados de los mockups de la clienta. Se reemplazan cuando llegue la identidad oficial.

## Contenido

```
shared/
├── design/
│   ├── tokens.json      ← FUENTE DE VERDAD: colores, tipografías, bordes, espaciados
│   └── tokens.css       ← generado: variables CSS para la landing u otra web
└── kuusense_ui/         ← paquete Flutter que usan ambas apps
    ├── assets/
    │   ├── brand/       logo.png (logo completo), symbol.png (solo la mascota/símbolo)
    │   ├── fonts/       archivos de las tipografías de marca
    │   └── images/      ilustraciones y fondos compartidos
    └── lib/src/
        ├── generated/tokens.g.dart  ← generado desde tokens.json
        ├── theme.dart               tema claro/oscuro de las apps
        ├── brand.dart               logo, fondo de marca, rutas de assets
        └── validators.dart          validaciones de formularios
```

## Cuando llegue la identidad oficial

1. **Colores:** edita `design/tokens.json` y corre `make tokens`. Se actualizan las dos apps y el CSS.
2. **Logo:** copia los archivos a `kuusense_ui/assets/brand/` como `logo.png` y `symbol.png` (PNG transparente; idealmente también en `@2x` y `@3x`). Mientras no existan, las apps muestran el nombre "KúuSense" como texto con los colores de marca.
3. **Tipografías:** copia los `.ttf`/`.otf` a `kuusense_ui/assets/fonts/`, decláralas en `kuusense_ui/pubspec.yaml` (hay un ejemplo comentado) y pon sus nombres en `font.heading` / `font.body` de `tokens.json`. Después corre `make tokens`.
4. **Landing:** importa `design/tokens.css` y usa las variables (`var(--kuu-color-brand-primary)`, etc.). Los logos y fuentes están en `kuusense_ui/assets/`.

## Reglas

- **Nunca escribas colores ni tamaños sueltos en las apps.** Usa el tema (`Theme.of(context)`) o los tokens (`KuuColor`, `KuuSpacing`, `KuuRadius`).
- Los archivos generados (`tokens.g.dart` y `tokens.css`) no se editan a mano.
- Los colores del semáforo (`state.stable`, `state.alert`, `state.preCrisis`) se acceden con `Theme.of(context).extension<KuuStateColors>()`.
