# INSTRUCCIONES PARA ESTE PROUYECT

## Flujo de trabajo para cambios

### Regla de compatibilidad

Cuando se despliega un cambio de backend a Render, **toda app con un APK anterior debe seguir funcionando**.

| Si cambias | ¿Seguro? |
|------------|----------|
| Endpoint nuevo | ✅ Seguro — app vieja no lo llama |
| Campo nuevo en endpoint existente | ✅ Seguro — app vieja ignora campos extra |
| Campo obligatorio nuevo | ❌ **Peligro** — app vieja no lo envía y el endpoint falla |
| Eliminar campo de endpoint | ❌ **Peligro** — app vieja espera ese campo |
| Renombrar campo | ❌ **Peligro** — app vieja usa el nombre anterior |

### Flujo de trabajo semanal

```
Tú haces cambios locales
       │
       ▼
Quedan registrados en "Cambios a revisar.md"
       │       ┌── Backend compatible: se sube a Render INMEDIATAMENTE
       │       └── Frontend: se acumula para APK semanal
       │
       ▼
Fin de semana → Revisas "Cambios a revisar.md"
       │
       ├── Subes cambios de backend pendientes a Render
       └── Build APK con todos los frontend pendientes → envías a Brenda
```

### Registro de cambios pendientes

Cada cambio en `Cambios a revisar.md` debe incluir:

- **Fecha** del cambio
- **Tipo**: Backend / Frontend / Ambos
- **Descripción** de lo que se cambió
- **BD**: Si requiere cambio en BD (nuevos campos, colecciones)
- **Compatibilidad**: Si rompe la app anterior (SÍ/NO)
- **Estado**: Pendiente / Desplegado / Enviado
