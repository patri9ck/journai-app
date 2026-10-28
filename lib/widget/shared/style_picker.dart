// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Patrick Zwick

import 'package:flutter/material.dart';

import '../../messages/app_localizations.dart';
import '../../model/poster_style.dart';
import '../../model/stamp_style.dart';
import 'stamp_font.dart';

class StyleSheetFrame extends StatelessWidget {
  final String title;
  final Widget? preview;
  final List<Widget> sections;
  final VoidCallback onReset;
  final VoidCallback? onSave;

  const StyleSheetFrame({
    super.key,
    required this.title,
    this.preview,
    required this.sections,
    required this.onReset,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Center(child: preview),
            ],
            for (final section in sections) ...[
              const SizedBox(height: 16),
              section,
            ],
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onReset, child: Text(localizations.stampReset)),
            const SizedBox(height: 8),
            FilledButton(onPressed: onSave, child: Text(localizations.documentSave)),
          ],
        ),
      ),
    );
  }
}

class StyleSection extends StatelessWidget {
  final String label;
  final Widget child;

  const StyleSection({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class StyleChoices<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  const StyleChoices({super.key, required this.values, required this.selected, required this.label, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(label(value)),
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

class ColorChoices extends StatelessWidget {
  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;

  const ColorChoices({super.key, required this.colors, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in colors)
          GestureDetector(
            onTap: () => onSelected(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: color == selected ? colorScheme.primary : colorScheme.outlineVariant,
                  width: color == selected ? 3 : 1,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: color == selected
                  ? Icon(Icons.check, size: 18, color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class FontChoices extends StatelessWidget {
  final String label;
  final StampFont selected;
  final ValueChanged<StampFont> onSelected;

  const FontChoices({super.key, required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StyleSection(
      label: label,
      child: StyleChoices(
        values: StampFont.values,
        selected: selected,
        label: (font) => stampFontLabel(localizations, font),
        onSelected: onSelected,
      ),
    );
  }
}

class HeadingField extends StatefulWidget {
  final String value;
  final String defaultHeading;
  final ValueChanged<String> onChanged;

  const HeadingField({super.key, required this.value, required this.defaultHeading, required this.onChanged});

  @override
  State<HeadingField> createState() => _HeadingFieldState();
}

class _HeadingFieldState extends State<HeadingField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(HeadingField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLength: 40,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: widget.defaultHeading, border: const OutlineInputBorder()),
      onChanged: widget.onChanged,
    );
  }
}

List<Widget> posterStyleSections(
  AppLocalizations localizations,
  PosterStyle style,
  String defaultHeading,
  ValueChanged<PosterStyle> onChanged,
) => [
  StyleSection(
    label: localizations.posterHeading,
    child: HeadingField(
      value: style.heading,
      defaultHeading: defaultHeading,
      onChanged: (heading) => onChanged(style.copyWith(heading: heading)),
    ),
  ),
  FontChoices(
    label: localizations.posterHeadingFont,
    selected: style.headingFont,
    onSelected: (headingFont) => onChanged(style.copyWith(headingFont: headingFont)),
  ),
  StyleSection(
    label: localizations.posterBackground,
    child: ColorChoices(
      colors: posterBackgrounds,
      selected: style.background,
      onSelected: (background) => onChanged(style.copyWith(background: background)),
    ),
  ),
  StyleSection(
    label: localizations.posterFrame,
    child: StyleChoices(
      values: PosterFrame.values,
      selected: style.frame,
      label: (frame) => switch (frame) {
        PosterFrame.none => localizations.posterFrameNone,
        PosterFrame.line => localizations.posterFrameLine,
        PosterFrame.double => localizations.posterFrameDouble,
      },
      onSelected: (frame) => onChanged(style.copyWith(frame: frame)),
    ),
  ),
  if (style.frame != PosterFrame.none)
    StyleSection(
      label: localizations.posterFrameColor,
      child: ColorChoices(
        colors: stampColors,
        selected: style.frameColor,
        onSelected: (frameColor) => onChanged(style.copyWith(frameColor: frameColor)),
      ),
    ),
];
