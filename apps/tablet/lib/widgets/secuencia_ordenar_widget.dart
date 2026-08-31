import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import '../tts.dart';

/// Renderiza `secuencia_ordenar`: la persona reordena los pasos con dos botones
/// grandes (subir / bajar) por fila. Se evitó el ARRASTRE a propósito —igual que
/// en `arrastrar_posicion`— porque es muy difícil con temblor/Alzheimer, el
/// público objetivo. No hay solución en el render → registra
/// {orden_final:[textos], movimientos}.
class SecuenciaOrdenarWidget extends StatefulWidget {
  final Instancia instancia;
  final ValueChanged<Map<String, dynamic>> onMetricas;

  const SecuenciaOrdenarWidget(
      {super.key, required this.instancia, required this.onMetricas});

  @override
  State<SecuenciaOrdenarWidget> createState() => _SecuenciaOrdenarWidgetState();
}

class _SecuenciaOrdenarWidgetState extends State<SecuenciaOrdenarWidget> {
  late List<String> _pasos;
  int _movimientos = 0;
  final DateTime _inicio = DateTime.now();

  @override
  void initState() {
    super.initState();
    final render = widget.instancia.render;
    final barajados = (render['pasos_barajados'] as List? ?? []);
    _pasos = barajados
        .whereType<Map>()
        .map((e) => (Map<String, dynamic>.from(e)['paso'] ?? '').toString())
        .toList();
  }

  void _emitir() {
    widget.onMetricas({
      'orden_final': List<String>.from(_pasos),
      'movimientos': _movimientos,
      'tiempo_ms': DateTime.now().difference(_inicio).inMilliseconds,
    });
  }

  // Índice de la fila recién movida, para resaltarla (si no, tras tocar 'Subir'
  // toda la lista salta y el mayor no ve cuál acaba de mover).
  int? _ultimoMovido;

  // Paso "cogido" con el primer toque (modo tocar-y-colocar): con el segundo
  // toque en otra fila, el paso salta directo a ese sitio. Evita tener que rodar
  // flecha a flecha cuando algo está al final de la lista (apunte de Saulo).
  int? _cogido;

  /// Mueve el paso de la posición `i` una posición arriba (-1) o abajo (+1).
  void _mover(int i, int delta) {
    final destino = i + delta;
    if (destino < 0 || destino >= _pasos.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      final item = _pasos.removeAt(i);
      _pasos.insert(destino, item);
      _movimientos++;
      _ultimoMovido = destino;
      _cogido = null;
    });
    _emitir();
  }

  /// Toque en una fila (no en las flechas): 1er toque = coge ese paso; 2º toque
  /// en otra fila = lo coloca ahí (se inserta en esa posición). Volver a tocar el
  /// mismo lo suelta sin mover.
  void _tocarFila(int i) {
    HapticFeedback.selectionClick();
    if (_cogido == null) {
      // Voz: el mayor con baja visión necesita oír que cogió el paso y qué hacer.
      Tts.instance.hablar('Has cogido: ${_pasos[i]}. Ahora toca dónde va.');
      setState(() => _cogido = i);
      return;
    }
    if (_cogido == i) {
      Tts.instance.hablar('Lo has soltado.');
      setState(() => _cogido = null);
      return;
    }
    final movido = _pasos[_cogido!];
    setState(() {
      final item = _pasos.removeAt(_cogido!);
      _pasos.insert(i, item);
      _movimientos++;
      _ultimoMovido = i;
      _cogido = null;
    });
    Tts.instance.hablar('Colocado: $movido.');
    _emitir();
  }

  /// ¿Todos los pasos son números? (p. ej. "Ordena los números"): entonces el
  /// badge de posición numérico confunde y se sustituye por una viñeta.
  bool get _pasosSonNumeros =>
      _pasos.every((p) => int.tryParse(p.trim()) != null);

  @override
  Widget build(BuildContext context) {
    final render = widget.instancia.render;
    final instruccion = render['instruccion'] as String? ?? 'Ordena los pasos';
    final titulo = render['titulo'] as String?;

    return LayoutBuilder(
      builder: (context, c) {
        // Móvil vertical: viewport estrecho o bajo. La misma tablet apaisada
        // usa la rama ancha (idéntica a antes).
        final estrecho = c.maxWidth < 520 || c.maxHeight < 640;

        final cabecera = <Widget>[
          Text(instruccion,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: estrecho ? 22 : 26, color: TrazoColors.ink)),
          if (titulo != null && titulo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: estrecho ? 16 : 18, color: TrazoColors.sageDark)),
          ],
          const SizedBox(height: 6),
          // Dirección explícita + cómo se ordena. Cambia cuando hay un paso
          // "cogido" para guiar el segundo toque (tocar-y-colocar).
          Container(
            margin: EdgeInsets.symmetric(horizontal: estrecho ? 0 : 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: _cogido != null
                ? BoxDecoration(
                    color: TrazoColors.sage.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TrazoColors.sageDark, width: 2))
                : null,
            child: Text(
                _cogido != null
                    ? 'Ahora toca la fila donde debe ir «${_pasos[_cogido!]}»'
                    : 'Pon ARRIBA lo que va primero. Toca un paso y luego dónde va (o usa las flechas).',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: estrecho ? 16 : 19,
                    fontWeight:
                        _cogido != null ? FontWeight.w700 : FontWeight.w400,
                    color: TrazoColors.ink)),
          ),
          SizedBox(height: estrecho ? 12 : 16),
        ];

        // En móvil: todo dentro de UN scroll (cabecera + filas), con la lista
        // sin scroll propio para que nada quede atrapado ni fuera de pantalla.
        if (estrecho) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                ...cabecera,
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pasos.length,
                  itemBuilder: (context, i) => _fila(i, estrecho: true),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }

        // Tablet apaisada: layout que llena la pantalla (idéntico al original).
        return Column(
          children: [
            ...cabecera,
            Expanded(
              child: ListView.builder(
                itemCount: _pasos.length,
                itemBuilder: (context, i) => _fila(i, estrecho: false),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Una fila (paso) con su viñeta, texto y los botones subir/bajar. En móvil
  /// se aprietan las separaciones para que los dos botones no se salgan.
  Widget _fila(int i, {required bool estrecho}) {
    final esPrimero = i == 0;
    final esUltimo = i == _pasos.length - 1;
    final movido = _ultimoMovido == i;
    final cogido = _cogido == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: estrecho ? 10 : 16, vertical: 12),
        decoration: BoxDecoration(
          // El paso COGIDO se resalta en coral (esperando dónde colocarlo); la
          // fila recién movida, en verde, para no perder el hilo.
          color: cogido
              ? const Color(0xFFFBEFE4)
              : movido
                  ? TrazoColors.sage.withValues(alpha: 0.20)
                  : TrazoColors.card,
          border: Border.all(
              color: cogido
                  ? TrazoColors.coralDark
                  : movido
                      ? TrazoColors.sageDark
                      : TrazoColors.sand,
              width: (cogido || movido) ? 2.5 : 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Zona de TOCAR-Y-COLOCAR: badge + texto (NO cubre las flechas, para
            // que tocar una flecha no se confunda con "coger" el paso).
            Expanded(
              child: GestureDetector(
                key: ValueKey('fila|$i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _tocarFila(i),
                child: Row(
                  children: [
                    // Viñeta de posición: número salvo que los pasos SEAN
                    // números (entonces confundiría cuál es cuál).
                    CircleAvatar(
                      backgroundColor: TrazoColors.sageDark,
                      foregroundColor: Colors.white,
                      child: Text(_pasosSonNumeros ? '•' : '${i + 1}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: estrecho ? 10 : 16),
                    Expanded(
                      child: Text(_pasos[i],
                          style: TextStyle(
                              fontSize: estrecho ? 18 : 22,
                              color: TrazoColors.ink)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: estrecho ? 6 : 8),
            // Botones grandes de subir / bajar (objetivo táctil amplio).
            _FlechaOrden(
              key: ValueKey('subir|$i'),
              icono: Icons.keyboard_arrow_up,
              etiqueta: 'Subir',
              activo: !esPrimero,
              onTap: () => _mover(i, -1),
            ),
            SizedBox(width: estrecho ? 8 : 16),
            _FlechaOrden(
              key: ValueKey('bajar|$i'),
              icono: Icons.keyboard_arrow_down,
              etiqueta: 'Bajar',
              activo: !esUltimo,
              onTap: () => _mover(i, 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón grande de flecha para reordenar por toque (accesible con temblor).
class _FlechaOrden extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  const _FlechaOrden({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiqueta,
      button: true,
      enabled: activo,
      child: InkWell(
        onTap: activo ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: activo ? TrazoColors.sageDark : TrazoColors.sand,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono,
              size: 40, color: activo ? Colors.white : TrazoColors.sageDark),
        ),
      ),
    );
  }
}
