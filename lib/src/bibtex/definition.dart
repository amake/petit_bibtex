import 'package:petitparser/definition.dart';
import 'package:petitparser/parser.dart';

import 'model.dart';

/// Grammar definition for BibTeX files.
///
/// Adapted from the grammar published by Oscar Nierstrasz at
/// https://twitter.com/onierstrasz/status/1621600391946289155.
class BibTeXDefinition extends GrammarDefinition<List<BibTeXEntry>> {
  @override
  Parser<List<BibTeXEntry>> start() => ref0(entries).end();

  // Entries
  Parser<List<BibTeXEntry>> entries() => ref0(entry)
      .starSeparated(whitespace().star())
      .map((list) => list.elements);
  Parser<BibTeXEntry> entry() => seq6(
          type.trim(),
          char('{').trim(),
          citeKey.trim(),
          char(',').trim(),
          ref0(fields),
          // optional trailing comma
          char(',').optional().trim() & char('}').trim())
      .map6((type, _, key, __, fields, ___) =>
          BibTeXEntry(type: type, key: key, fields: fields));

  // Fields
  Parser<Map<String, String>> fields() => ref0(field)
      .starSeparated(char(',').trim())
      .map((list) => Map.fromEntries(list.elements));
  Parser<MapEntry<String, String>> field() =>
      seq3(fieldName.trim(), char('=').trim(), ref0(fieldValue))
          .map3((name, _, value) => MapEntry(name, value));
  Parser<String> fieldValue() => [
        ref0(fieldValueInQuotes),
        ref0(fieldValueInBraces),
        rawString,
      ].toChoiceParser();

  // Quoted strings
  Parser<String> fieldValueInQuotes() =>
      seq3(char('"'), ref0(fieldStringWithinQuotes), char('"'))
          .flatten("quoted string expected");
  Parser<List> fieldStringWithinQuotes() =>
      [ref0(fieldCharWithinQuotes), escapeChar].toChoiceParser().star();
  Parser<String> fieldCharWithinQuotes() => pattern(r'^\"');

  // Braced strings
  Parser<String> fieldValueInBraces() =>
      seq3(char('{'), ref0(fieldStringWithinBraces), char('}'))
          .flatten("braced string expected");

  Parser<List> fieldStringWithinBraces() => [
        ref0(fieldCharWithinBraces),
        escapeChar,
        seq3(char('{'), ref0(fieldStringWithinBraces), char('}'))
      ].toChoiceParser().star();

  Parser<String> fieldCharWithinBraces() => pattern(r'^\{}');

  // Basic strings
  final type = letter().plusString("type expected").skip(before: char('@'));
  final citeKey =
      (anyOf(',{}') | whitespace()).neg().plusString("citation key expected");
  final fieldName = pattern('a-zA-Z0-9_-').plusString("field name expected");
  // Allow for URLs, except if they contain a comma
  final rawString =
      pattern(r'a-zA-Z0-9!#$%&()+./:;=?@_-').plusString("raw string expected");

  // Other tokens
  final escapeChar = seq2(char(r'\'), any());
}
