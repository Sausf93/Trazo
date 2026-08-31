import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/reto_cruzar_widget.dart';
import '../widgets/reto_garrafas_widget.dart';
import '../widgets/reto_hanoi_widget.dart';
import '../widgets/reto_mastermind_widget.dart';
import '../widgets/reto_ranas_widget.dart';

/// Sección "Retos de ingenio": juegos de lógica interactivos para resolver EN
/// GRUPO (con papel y lápiz si hace falta). Son actividades MUY especiales, para
/// participantes avanzados; por eso viven aquí, aparte, y NUNCA entran en la
/// planificación normal de un usuario ni miden su desempeño individual.
class RetosScreen extends StatelessWidget {
  const RetosScreen({super.key});

  static const _garrafas = <RetoGarrafas>[
    RetoGarrafas(
      titulo: 'Garrafas: medir 4 litros (3 y 5)',
      enunciado:
          'Tenéis una garrafa de 3 L y otra de 5 L, y un grifo. ¿Cómo dejáis '
          'exactamente 4 litros en una garrafa?',
      capacidades: [5, 3],
      objetivo: 4,
    ),
    RetoGarrafas(
      titulo: 'Garrafas: medir 4 litros (5 y 8)',
      enunciado:
          'Con una garrafa de 5 L, otra de 8 L y un grifo, dejad exactamente '
          '4 litros en una de ellas.',
      capacidades: [8, 5],
      objetivo: 4,
    ),
    RetoGarrafas(
      titulo: 'Garrafas: repartir sin grifo (8, 5 y 3)',
      enunciado:
          'La garrafa de 8 L está LLENA; las de 5 L y 3 L, vacías. Sin grifo '
          '(solo verter de una a otra), dejad 4 litros en una garrafa.',
      capacidades: [8, 5, 3],
      iniciales: [8, 0, 0],
      objetivo: 4,
      conGrifo: false,
    ),
    RetoGarrafas(
      titulo: 'Garrafas: medir 6 litros (4 y 9)',
      enunciado:
          'Con una garrafa de 4 L, otra de 9 L y un grifo, dejad exactamente '
          '6 litros en una de ellas.',
      capacidades: [9, 4],
      objetivo: 6,
    ),
  ];

  static const _cruzar = <RetoCruzar>[
    RetoCruzar(
      titulo: 'El barquero (el lobo, la cabra y la col)',
      enunciado:
          'El barquero tiene que pasar al otro lado el LOBO, la CABRA y la COL. '
          'En la barca solo caben el barquero y una cosa. Si los deja solos: el '
          'lobo se come a la cabra, y la cabra se come la col. ¿Cómo lo hace?',
      entidades: [
        CruzarEntidad(id: 'granjero', nombre: 'Barquero', emoji: '🧑‍🌾'),
        CruzarEntidad(id: 'lobo', nombre: 'Lobo', emoji: '🐺'),
        CruzarEntidad(id: 'cabra', nombre: 'Cabra', emoji: '🐐'),
        CruzarEntidad(id: 'col', nombre: 'Col', emoji: '🥬'),
      ],
      capacidadBarca: 2,
      remero: 'granjero',
      incompatibles: [
        ['lobo', 'cabra'],
        ['cabra', 'col']
      ],
    ),
    RetoCruzar(
      titulo: 'Misioneros y caníbales',
      enunciado:
          'Tres MISIONEROS y tres CANÍBALES quieren cruzar el río. En la barca '
          'caben dos. En ninguna orilla puede haber más caníbales que misioneros '
          '(o se los comen). ¿Cómo cruzan todos?',
      entidades: [
        CruzarEntidad(id: 'mis1', nombre: 'Misionero', emoji: '🧑', tipo: 'mis'),
        CruzarEntidad(id: 'mis2', nombre: 'Misionero', emoji: '🧑', tipo: 'mis'),
        CruzarEntidad(id: 'mis3', nombre: 'Misionero', emoji: '🧑', tipo: 'mis'),
        CruzarEntidad(id: 'can1', nombre: 'Caníbal', emoji: '😈', tipo: 'can'),
        CruzarEntidad(id: 'can2', nombre: 'Caníbal', emoji: '😈', tipo: 'can'),
        CruzarEntidad(id: 'can3', nombre: 'Caníbal', emoji: '😈', tipo: 'can'),
      ],
      capacidadBarca: 2,
      mayoria: MayoriaRegla(debil: 'mis', fuerte: 'can'),
    ),
  ];

  void _abrir(BuildContext context, String titulo, Widget juego) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _RetoJugar(titulo: titulo, juego: juego),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrazoColors.ivory,
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: const Text('Retos de ingenio'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: TrazoColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Juegos de lógica para resolver EN GRUPO, entre los que van sobrados. '
              'Pensadlos juntos, con papel y lápiz si hace falta; la tablet os '
              'deja probar y avisa cuando lo conseguís. No cuentan como sesión.',
              style: TextStyle(
                  fontSize: 16, color: TrazoColors.ink, height: 1.3),
            ),
          ),
          const _Titulo('Garrafas de agua'),
          for (final r in _garrafas)
            _TarjetaReto(
              titulo: r.titulo,
              icono: Icons.water_drop,
              onAbrir: () => _abrir(context, r.titulo, RetoGarrafasWidget(reto: r)),
            ),
          const SizedBox(height: 12),
          const _Titulo('Cruzar el río'),
          for (final r in _cruzar)
            _TarjetaReto(
              titulo: r.titulo,
              icono: Icons.directions_boat,
              onAbrir: () => _abrir(context, r.titulo, RetoCruzarWidget(reto: r)),
            ),
          const SizedBox(height: 12),
          const _Titulo('Las ranas que saltan'),
          _TarjetaReto(
            titulo: 'Las ranas que saltan (fácil, 2 y 2)',
            icono: Icons.pest_control,
            onAbrir: () => _abrir(
                context,
                'Las ranas que saltan (fácil)',
                const RetoRanasWidget(
                    reto: RetoRanas(
                        titulo: 'Las ranas que saltan',
                        enunciado:
                            'Dos ranas verdes y dos marrones, con una piedra vacía '
                            'en medio. Las verdes solo van a la derecha y las marrones '
                            'a la izquierda: un paso a una piedra vacía o un salto por '
                            'encima de UNA rana. Intercambiadlas.',
                        porLado: 2))),
          ),
          _TarjetaReto(
            titulo: 'Las ranas que saltan (3 y 3)',
            icono: Icons.pest_control,
            onAbrir: () => _abrir(
                context,
                'Las ranas que saltan',
                const RetoRanasWidget(
                    reto: RetoRanas(
                        titulo: 'Las ranas que saltan',
                        enunciado:
                            'Tres ranas verdes y tres marrones, con una piedra vacía '
                            'en medio. Las verdes solo van a la derecha y las marrones '
                            'a la izquierda: un paso a una piedra vacía o un salto por '
                            'encima de UNA rana. Intercambiad los dos grupos.',
                        porLado: 3))),
          ),
          const SizedBox(height: 12),
          const _Titulo('La torre de Hanoi'),
          _TarjetaReto(
            titulo: 'La torre de Hanoi (3 discos)',
            icono: Icons.view_agenda,
            onAbrir: () => _abrir(
                context,
                'La torre de Hanoi (3 discos)',
                const RetoHanoiWidget(
                    reto: RetoHanoi(
                        titulo: 'La torre de Hanoi',
                        enunciado:
                            'Pasad toda la torre al último palo. Se mueve un disco '
                            'cada vez y nunca un disco grande encima de uno pequeño.',
                        discos: 3))),
          ),
          _TarjetaReto(
            titulo: 'La torre de Hanoi (4 discos)',
            icono: Icons.view_agenda,
            onAbrir: () => _abrir(
                context,
                'La torre de Hanoi (4 discos)',
                const RetoHanoiWidget(
                    reto: RetoHanoi(
                        titulo: 'La torre de Hanoi',
                        enunciado:
                            'Pasad toda la torre de 4 discos al último palo. Un disco '
                            'cada vez y nunca uno grande sobre uno pequeño.',
                        discos: 4))),
          ),
          const SizedBox(height: 12),
          const _Titulo('Adivina los colores (Mastermind)'),
          for (final nc in const [3, 4, 5, 6])
            _TarjetaReto(
              titulo: nc == 3
                  ? 'Adivina los colores (fácil, 3)'
                  : nc == 4
                      ? 'Adivina los colores (medio, 4)'
                      : nc == 5
                          ? 'Adivina los colores (difícil, 5)'
                          : 'Adivina los colores (muy difícil, 6)',
              icono: Icons.palette,
              onAbrir: () => _abrir(
                  context,
                  'Adivina los colores',
                  RetoMastermindWidget(
                      reto: RetoMastermind(
                          titulo: 'Adivina los colores',
                          enunciado:
                              'Hay una fila secreta de 4 colores. Elegid una fila y pulsad Comprobar: os diré cuántos están en su sitio y cuántos son del color correcto pero en otro sitio.',
                          colores: nc,
                          longitud: 4))),
            ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: TrazoColors.sageDark)),
      );
}

class _TarjetaReto extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final VoidCallback onAbrir;
  const _TarjetaReto(
      {required this.titulo, required this.icono, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: TrazoColors.card,
          child: Icon(icono, color: TrazoColors.sageDark),
        ),
        title: Text(titulo,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TrazoColors.ink)),
        trailing: const Icon(Icons.play_circle_fill,
            color: TrazoColors.coralDark, size: 34),
        onTap: onAbrir,
      ),
    );
  }
}


/// Pantalla de juego del reto, en HORIZONTAL (los retos lucen y se juegan mejor
/// apaisados; en tablet ya suele estarlo, en móvil se fuerza). Al salir se
/// restauran todas las orientaciones.
class _RetoJugar extends StatefulWidget {
  final String titulo;
  final Widget juego;
  const _RetoJugar({required this.titulo, required this.juego});

  @override
  State<_RetoJugar> createState() => _RetoJugarState();
}

class _RetoJugarState extends State<_RetoJugar> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrazoColors.ivory,
      appBar: AppBar(
        backgroundColor: TrazoColors.ivory,
        title: Text(widget.titulo),
      ),
      body: SafeArea(child: widget.juego),
    );
  }
}
