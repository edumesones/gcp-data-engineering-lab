# Protocolo de verificación independiente

> Norma 2 del proyecto: **quien construye no verifica.**

## Por qué

Quien ha construido algo lo lee con la intención con la que lo escribió y ve lo que quería hacer, no lo
que hizo. Un verificador sin ese contexto solo puede juzgar lo que hay delante.

## Qué recibe el verificador

Un subagente **nuevo**, lanzado sin la conversación, con un prompt que contiene únicamente:

1. **El criterio de aceptación** del paso, copiado de `docs/diseno.md`
2. **Las rutas del artefacto**: código, SQL, DAG, lección, respuesta
3. **Cómo comprobarlo**: qué comandos puede ejecutar (siempre con `source entorno.sh` antes) y qué no
   puede tocar
4. Esta norma: **no inventar**. Si algo no se puede comprobar, se dice

## Qué NO recibe

- La conversación en la que se construyó
- Explicaciones de por qué se hizo así
- Notas, borradores o intentos fallidos
- El resultado esperado "para ayudar": solo el criterio

## Qué hace

- **Ejecuta** las comprobaciones cuando se pueden ejecutar. Leer código no es probarlo.
- Para las lecciones escritas: contrasta cada afirmación técnica con documentación oficial.
- **No arregla nada.** Reporta.

## Informe

`verificacion/{paso}-{fecha}.md`:

```markdown
# Verificación — Paso {n} · {fecha}

## Veredicto
PASA · PASA CON RESERVAS · NO PASA

## Criterio de aceptación
{copiado tal cual}

## Comprobaciones ejecutadas
| Comprobación | Cómo | Resultado |

## Hallazgos
| Gravedad | Dónde | Qué | Evidencia |

## Lo que no pude comprobar
⚠️ …
```

Un paso **no se da por terminado** sin informe en PASA. Si sale NO PASA, se corrige y se lanza **otro**
verificador nuevo, no el mismo.
