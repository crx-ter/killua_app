import 'package:highlight/highlight.dart' show Mode;
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/markdown.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/r.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/scala.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

final Map<String, Mode> lenguajesSoportados = {
  'dart': dart,
  'python': python,
  'javascript': javascript,
  'typescript': typescript,
  'java': java,
  'cpp': cpp,
  'json': json,
  'sql': sql,
  'html': xml,
  'css': css,
  'c': cpp,
  'csharp': cs,
  'go': go,
  'kotlin': kotlin,
  'swift': swift,
  'rust': rust,
  'php': php,
  'ruby': ruby,
  'bash': bash,
  'yaml': yaml,
  'markdown': markdown,
  'r': r,
  'scala': scala,
  'lua': lua,
};

final List<String> listaNombresLenguajes = lenguajesSoportados.keys.toList();
