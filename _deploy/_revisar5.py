import json
p = ("C:/Users/Saulo.Santacruz/.claude/projects/"
     "C--Users-Saulo-Santacruz-Desktop-Trazo/e3bc96b9-6db2-4825-b521-575f70d610a7/"
     "subagents/workflows/wf_91efe322-acf/journal.jsonl")


def find(x):
    if isinstance(x, dict):
        if 'actividades' in x and isinstance(x['actividades'], list):
            return x['actividades']
        for v in x.values():
            f = find(v)
            if f:
                return f
    elif isinstance(x, list):
        for v in x:
            f = find(v)
            if f:
                return f
    return None


acts = None
for line in open(p, encoding='utf-8'):
    try:
        o = json.loads(line)
    except Exception:
        continue
    acts = find(o)
    if acts:
        break

json.dump(acts, open('_deploy/contenido3.json', 'w', encoding='utf-8'),
          ensure_ascii=False, indent=1)
print('actividades lote 5:', len(acts))
for a in acts:
    items = a['parametros_json']['items']
    tipo = 'img' if any('imagen' in it for it in items) else 'txt'
    print(' - [%s] %s | %s (%d)' % (tipo, a['bloque'], a['nombre'], len(items)))
print('=== ITEMS DE TEXTO (revisar correcta) ===')
for a in acts:
    for it in a['parametros_json']['items']:
        if 'imagen' not in it:
            en = it.get('enunciado', '')
            print('  * [%s] %s  <-  %s %s' % (a['nombre'], it['correcta'],
                  it.get('instruccion', ''), en[:75]))
