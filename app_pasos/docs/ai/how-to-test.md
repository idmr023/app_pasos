# How To Test (AI)

<!-- AGENTSGEN:START section=how_to_test -->
- Project: `app_pasos`
- Stack profile: static

## Commands
- Fast check: `(not detected)`
- Full check: `(not detected)`
- Tests: `(not detected)`
- Lint: `(not detected)`
- Format: `(not detected)`

## Policy
- Run fast checks while editing.
- Run full checks before final output.
- If commands are placeholders, set explicit values in `.agentsgen.json`.
<!-- AGENTSGEN:END section=how_to_test -->

## Comandos reales

```bash
# Backend (desde backend/)
npm test                 # motor de progresión de carga (node:test, sin dependencias)
npm run dev              # probar endpoints a mano (puerto 3000)

# Flutter (desde app_pasos/)
flutter analyze
flutter test
```

Prueba manual de progresión de carga: ver `docs/PLAN_PROGRESION_DE_CARGA.md`, sección 6.
