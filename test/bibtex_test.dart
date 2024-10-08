import 'package:http/http.dart' as http;
import 'package:petit_bibtex/bibtex.dart';
import 'package:petitparser/reflection.dart';
import 'package:test/test.dart';

Matcher isBibTextEntry({
  dynamic type = anything,
  dynamic key = anything,
  dynamic fields = anything,
}) =>
    const TypeMatcher<BibTeXEntry>()
        .having((entry) => entry.type, 'type', type)
        .having((entry) => entry.key, 'key', key)
        .having((entry) => entry.fields, 'fields', fields);

void main() {
  final parser = BibTeXDefinition().build();
  test('linter', () {
    expect(linter(parser, excludedTypes: {}), isEmpty);
  });
  group('basic', () {
    const input = '@inproceedings{Reng10c,\n'
        '\tTitle = "Practical Dynamic Grammars for Dynamic Languages",\n'
        '\tAuthor = {Lukas Renggli and St\\\'ephane Ducasse and Tudor G\\^irba and Oscar Nierstrasz},\n'
        '\tMonth = jun,\n'
        '\tYear = 2010,\n'
        '\tUrl = {http://scg.unibe.ch/archive/papers/Reng10cDynamicGrammars.pdf}}';
    final entry = parser.parse(input).value.single;
    test('parsing', () {
      expect(
          entry,
          isBibTextEntry(type: 'inproceedings', key: 'Reng10c', fields: {
            'Title': '"Practical Dynamic Grammars for Dynamic Languages"',
            'Author': '{Lukas Renggli and St\\\'ephane Ducasse and '
                'Tudor G\\^irba and Oscar Nierstrasz}',
            'Month': 'jun',
            'Year': '2010',
            'Url': '{http://scg.unibe.ch/archive/papers/'
                'Reng10cDynamicGrammars.pdf}',
          }));
    });
    test('serializing', () {
      expect(entry.toString(), input);
    });
  });
  group('edge cases', () {
    test('plus in key', () {
      // From https://en.wikipedia.org/wiki/BibTeX#Database_files
      const input = '''@Book{abramowitz+stegun,
 author    = "Milton {Abramowitz} and Irene A. {Stegun}",
 title     = "Handbook of Mathematical Functions with
              Formulas, Graphs, and Mathematical Tables",
 publisher = "Dover",
 year      =  1964,
 address   = "New York City",
 edition   = "ninth Dover printing, tenth GPO printing"
}''';
      final entry = parser.parse(input).value.single;
      expect(entry, isBibTextEntry(key: 'abramowitz+stegun'));
    });
    test('trailing comma', () {
      // From https://www.bibtex.com/e/entry-types/#article
      const input = '''@article{CitekeyArticle,
  author   = "P. J. Cohen",
  title    = "The independence of the continuum hypothesis",
  journal  = "Proceedings of the National Academy of Sciences",
  year     = 1963,
  volume   = "50",
  number   = "6",
  pages    = "1143--1148",
}''';
      final entry = parser.parse(input).value.single;
      expect(entry, isBibTextEntry());
      expect(entry.fields['pages'], '"1143--1148"');
    });
    test('hyphen in key', () {
      const input = '''@article{jiang-2019-mechan-proper,
  author =       {Bo Jiang and Wen Fang and Ruomeng Chen and Dongyu
                  Guo and Yinjie Huang and Chaolei Zhang and Yazheng
                  Liu},
  title =        {Mechanical Properties and Microstructural
                  Characterization of Medium Carbon Non-Quenched and
                  Tempered Steel - Microalloying Behavior},
  journal =      {Materials Science and Engineering: A},
  volume =       748,
  number =       {nil},
  pages =        {180-188},
  year =         2019,
  doi =          {10.1016/j.msea.2019.01.094},
  url =          {http://sci-hub.se/10.1016/j.msea.2019.01.094},
  DATE_ADDED =   {Fri Oct 28 17:16:26 2022},
}''';
      final entry = parser.parse(input).value.single;
      expect(entry, isBibTextEntry(key: 'jiang-2019-mechan-proper'));
    });
    test('non-ASCII key', () {
      const input = '''@article{王家聪-2016-xg720,
  author =       {王家聪 and 罗海霞 and 杨立志 and 韦金钰 and 叶海燕},
  title =        {油缸用高强韧性冷拔新材料XG720的开发},
  journal =      {钢管},
  url =          {https://www.doc88.com/p-3157461926925.html},
  volume =       45,
  number =       6,
  pages =        {9--14},
  year =         2016,
}''';
      final entry = parser.parse(input).value.single;
      expect(entry, isBibTextEntry(key: '王家聪-2016-xg720'));
    });
    test('raw string URL', () {
      const input = '''@article{陈卓-2019,
  author =       {陈卓},
  title =        {极薄取向硅钢制备方法的进步及需求研究},
  journal =      {电工钢},
  volume =       1,
  number =       1,
  pages =        {5-7},
  year =         2019,
  url =
                  http://www.bwjournal.com/dgg/CN/abstract/article_7273.shtml?q=foo,
  eid =          5,
  keywords =     {极薄取向硅钢；生产；工艺变化；需求分析及预测},
  publisher =    {电工钢},
}''';
      final entry = parser.parse(input).value.single;
      expect(entry, isBibTextEntry());
      expect(entry.fields['url'],
          'http://www.bwjournal.com/dgg/CN/abstract/article_7273.shtml?q=foo');
    });
  });
  group('scg.bib', () {
    late final List<BibTeXEntry> entries;
    setUpAll(() async {
      final body = await http.read(Uri.parse(
          'https://raw.githubusercontent.com/scgbern/scgbib/main/scg.bib'));
      entries = parser.parse(body).value;
    });
    test('size', () {
      expect(entries.length, greaterThan(9600));
      expect(
          entries
              .where((entry) =>
                  entry.fields['Author']?.contains('Renggli') ?? false)
              .length,
          greaterThan(35));
    });
    test('round-trip', () {
      for (final entry in entries) {
        expect(
            parser.parse(entry.toString()).value.single,
            isBibTextEntry(
                type: entry.type, key: entry.key, fields: entry.fields));
      }
    });
  }, onPlatform: const {
    'js': [Skip('http.get is unsupported in JavaScript')],
  });
}
