# Makefile

# ファイル設定
DATE := $(shell date +%Y%m%d%H)
CSV_WITH_HEADER = user_dict.csv
CSV_NO_HEADER = /tmp/user_dict.csv
OUTPUT_DIC = user_dict_${DATE}.dic
SYSTEM_DIC = system_core.dic
# https://github.com/WorksApplications/Sudachi/releases/tag/v0.7.5
JAR = sudachi-0.7.5.jar

# デフォルトターゲット
all: $(OUTPUT_DIC)

# ヘッダーを除去して中間ファイルを生成
$(CSV_NO_HEADER): $(CSV_WITH_HEADER)
	tail -n +2 $< > $@

# ユーザー辞書をビルド
$(OUTPUT_DIC): $(CSV_NO_HEADER)
	java -Dfile.encoding=UTF-8 -cp $(JAR) com.worksap.nlp.sudachi.dictionary.UserDictionaryBuilder \
	  -o $(OUTPUT_DIC) -s $(SYSTEM_DIC) $(CSV_NO_HEADER)

# 中間ファイルを削除
clean:
	rm -f $(CSV_NO_HEADER) $(OUTPUT_DIC)
