import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/reto_cruzar_widget.dart';
import '../widgets/reto_garrafas_widget.dart';

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
          const SizedBox(height: 18),
          const _Titulo('Próximamente'),
          const _Proximo('Las ranas que saltan'),
          const _Proximo('La torre de Hanoi'),
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

class _Proximo extends StatelessWidget {
  final String texto;
  const _Proximo(this.texto);
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.55,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.lock_clock,
                  size: 20, color: TrazoColors.bordeControl),
              const SizedBox(width: 10),
              Text(texto,
                  style: const TextStyle(
                      fontSize: 16, color: TrazoColors.ink)),
            ],
          ),
        ),
      );
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
