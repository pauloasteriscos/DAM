enum AudioSpeedControlStyle {
  buttons('buttons'),
  slider('slider'),
  compact('compact');

  const AudioSpeedControlStyle(this.storageValue);

  final String storageValue;

  static AudioSpeedControlStyle fromStorage(String? value) {
    for (final style in values) {
      if (style.storageValue == value) {
        return style;
      }
    }

    return AudioSpeedControlStyle.buttons;
  }
}
