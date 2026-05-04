// =============================================================
//  InputHandler.pde  |  Buffer di testo per lo stato INPUT
// =============================================================

class InputHandler {

  StringBuilder buffer;
  int           maxLength = Config.maxCharPrompt;   // caratteri massimi

  InputHandler() {
    buffer = new StringBuilder();
  }

  void append(char c) {
    if (buffer.length() < maxLength) {
      buffer.append(c);
    }
  }

  void backspace() {
    if (buffer.length() > 0) {
      buffer.deleteCharAt(buffer.length() - 1);
    }
  }

  void clear() {
    buffer.setLength(0);
  }

  // Imposta un testo direttamente (usato dalla dev mode per i preset)
  void setText(String s) {
    buffer.setLength(0);
    buffer.append(s.substring(0, min(s.length(), maxLength)));
  }

  String getText() {
    return buffer.toString();
  }

  int length() {
    return buffer.length();
  }
}
