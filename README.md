# Groonga Index Selector plugin

config``index-selector.table``に設定されたテーブルのキーで検索された場合、そのテーブルにある同名のインデックスを使うようにexpressionを書き換えます。

例えば、https://github.com/naoa/groonga-token-filter-yatof のTokenFilterWhite を使って、特定のワードのみのWITH_POSITIONなしのインデックスを作ることによりそのワードの検索を高速化することを目的にしてます。

## Install

Install Groonga using --enable-mruby option

Build this function.

    % sh autogen.sh
    % ./configure
    % sudo make install

## Usage

Register `expression_rewriters/index_selector`:

    % groonga DB
    > plugin_register expression_rewriters/index_selector

Create expression_rewriters table

```
table_create expression_rewriters TABLE_HASH_KEY ShortText
column_create expression_rewriters plugin_name COLUMN_SCALAR Text
load --table expression_rewriters
[
{"_key": "index_selector", "plugin_name": "expression_rewriters/index_selector"}
]
```

Set use index selector table to config

```
config_set index-selector.table white_words
```

Set target key to table

```
table_create white_words TABLE_PAT_KEY ShortText --default_tokenizer TokenBigram --normalizer NormalizerAuto
load --table white_words
[
{"_key": "groonga"}
]
```

Create data table and same index to index selector table(``white_wods``)

```
table_create Entries TABLE_NO_KEY
column_create Entries title COLUMN_SCALAR ShortText
column_create Entries body COLUMN_SCALAR ShortText

table_create Terms TABLE_PAT_KEY ShortText --default_tokenizer TokenBigram
column_create Terms title COLUMN_INDEX|WITH_POSITION Entries title
load --table Entries
[
{"title": "Groonga and MySQL", "body": "Groonga PostgreSQL"}
]

column_create white_words title COLUMN_INDEX|WITH_POSITION Entries title
```

Now you can search `groonga` word using white_words.title index.

```
select Entries --filter 'title @ "groonga"'

[
  [
    0,
    0.0,
    0.0
  ],
  [
    [
      [
        1
      ],
      [
        [
          "_id",
          "UInt32"
        ],
        [
          "body",
          "ShortText"
        ],
        [
          "title",
          "ShortText"
        ]
      ],
      [
        1,
        "Groonga PostgreSQL",
        "Groonga and MySQL"
      ]
    ]
  ]
]
```

## License

Public domain. You can copy and modify this project freely.
