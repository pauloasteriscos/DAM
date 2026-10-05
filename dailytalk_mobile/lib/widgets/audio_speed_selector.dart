import 'package:flutter/material.dart';

import '../models/audio_speed_control_style.dart';

/// One behavioral contract with three interchangeable visual presentations.
///
/// All variants expose the same five values and the same callback. Choosing a
/// style never changes lesson semantics or the current speed.
final class AudioSpeedSelector extends StatelessWidget {
  const AudioSpeedSelector({
    super.key,
    required this.style,
    required this.speeds,
    required this.selectedSpeed,
    required this.onSelected,
    this.title = 'Velocidade do áudio',
    this.keyPrefix = 'mission-vocab-speed',
  });

  final AudioSpeedControlStyle style;
  final List<double> speeds;
  final double selectedSpeed;
  final ValueChanged<double> onSelected;
  final String? title;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      AudioSpeedControlStyle.buttons => _buildButtons(context),
      AudioSpeedControlStyle.slider => _buildSlider(context),
      AudioSpeedControlStyle.compact => _buildCompact(context),
    };
  }

  Widget _buildButtons(BuildContext context) {
    return _Panel(
      title: title,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final speed in speeds)
            ChoiceChip(
              key: ValueKey<String>('$keyPrefix-${_speedKey(speed)}'),
              label: Text(_formatSpeed(speed)),
              selected: selectedSpeed == speed,
              onSelected: (_) => onSelected(speed),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              selectedColor: const Color(0xFFDDF7ED),
              side: BorderSide(
                color: selectedSpeed == speed
                    ? const Color(0xFF18A875)
                    : const Color(0xFFD5E2E9),
              ),
              labelStyle: TextStyle(
                color: selectedSpeed == speed
                    ? const Color(0xFF087A57)
                    : const Color(0xFF425965),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlider(BuildContext context) {
    var selectedIndex = speeds.indexOf(selectedSpeed);
    if (selectedIndex < 0) {
      selectedIndex = speeds.indexOf(1);
    }
    if (selectedIndex < 0) {
      selectedIndex = 0;
    }

    return _Panel(
      title: title,
      child: Column(
        children: <Widget>[
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF168CFF),
              inactiveTrackColor: const Color(0xFFD9E5EC),
              thumbColor: const Color(0xFF168CFF),
              overlayColor: const Color(0x22168CFF),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
              activeTickMarkColor: const Color(0xFF8BC7FF),
              inactiveTickMarkColor: const Color(0xFFC8D7E0),
              trackHeight: 4,
            ),
            child: Slider(
              key: ValueKey<String>('$keyPrefix-slider'),
              value: selectedIndex.toDouble(),
              min: 0,
              max: (speeds.length - 1).toDouble(),
              divisions: speeds.length - 1,
              label: _formatSpeed(speeds[selectedIndex]),
              onChanged: (value) {
                final index = value.round().clamp(0, speeds.length - 1).toInt();
                onSelected(speeds[index]);
              },
            ),
          ),
          Row(
            children: <Widget>[
              for (final speed in speeds)
                Expanded(
                  child: Text(
                    _formatSpeed(speed),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: speed == selectedSpeed
                          ? const Color(0xFF168CFF)
                          : const Color(0xFF58707C),
                      fontSize: 11.5,
                      fontWeight: speed == selectedSpeed
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8E6EE)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x10071C25),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF4FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              size: 19,
              color: Color(0xFF168CFF),
            ),
          ),
          const SizedBox(width: 7),
          Container(width: 1, height: 26, color: const Color(0xFFD9E5EC)),
          const SizedBox(width: 7),
          for (final speed in speeds) ...<Widget>[
            Expanded(
              child: _CompactSpeedButton(
                key: ValueKey<String>('$keyPrefix-${_speedKey(speed)}'),
                label: _formatSpeed(speed),
                selected: speed == selectedSpeed,
                onTap: () => onSelected(speed),
              ),
            ),
            if (speed != speeds.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  static String _formatSpeed(double speed) =>
      '${speed % 1 == 0 ? speed.toStringAsFixed(0) : speed.toString()}x';

  static String _speedKey(double speed) =>
      speed.toString().replaceAll('.', '-');
}

final class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: Color(0xFF168CFF),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                      color: Color(0xFF29404B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          child,
        ],
      ),
    );
  }
}

final class _CompactSpeedButton extends StatelessWidget {
  const _CompactSpeedButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF168CFF) : const Color(0xFFF4F8FB),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? const Color(0xFF168CFF)
                  : const Color(0xFFE0E9EE),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF29404B),
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
