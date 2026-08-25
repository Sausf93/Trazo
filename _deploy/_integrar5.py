import json

cat_path = 'backend/api/app/data/catalogo.json'
acts = json.load(open('_deploy/contenido3.json', encoding='utf-8'))
txt = open(cat_path, encoding='utf-8').read()
existentes = {a['nombre'] for a in json.loads(txt)}

# Renombrar colisiones (mantener el contenido en vez de descartarlo).
renombres = {'¿Qué hace falta?': '¿Qué se usa para cada cosa?'}
for a in acts:
    if a['nombre'] in renombres:
        a['nombre'] = renombres[a['nombre']]

nuevas = [a for a in acts if a['nombre'] not in existentes]
descartadas = [a['nombre'] for a in acts if a['nombre'] in existentes]
if descartadas:
    print('descartadas por nombre duplicado:', descartadas)

bloques = [' ' + json.dumps(a, ensure_ascii=False, indent=1).replace('\n', '\n ')
           for a in nuevas]
nuevo = txt.rstrip().rstrip('\n')
i = nuevo.rfind(']')
nuevo = nuevo[:i].rstrip().rstrip('\n') + ',\n' + ',\n'.join(bloques) + '\n]\n'
data = json.loads(nuevo)
open(cat_path, 'w', encoding='utf-8').write(nuevo)
print('lote 5 insertadas:', len(nuevas), '| total actividades:', len(data))
