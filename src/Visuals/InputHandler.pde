// InputHandler.pde  |  Text buffer for the INPUT state
// Stores and edits the user prompt, enforces the maximum length, and supports direct text loading from developer presets.

class InputHandler {
  StringBuilder buffer;
  int           maxLength = Config.maxCharPrompt;   // Maximum number of characters

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

  // Replaces the current text, truncating it to the maximum allowed length
  // Used by DevMode to load prompt presets
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
