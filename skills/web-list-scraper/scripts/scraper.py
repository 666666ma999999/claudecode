#!/usr/bin/env python3
"""
汎用Webスクレイピングツール
リスト（Excel/CSV）とWebページを紐付けて詳細情報を取得
"""

import requests
from bs4 import BeautifulSoup
import csv
import json
import time
import re
from datetime import datetime
from typing import List, Dict, Optional, Any, Callable
from pathlib import Path

try:
    import openpyxl
    HAS_OPENPYXL = True
except ImportError:
    HAS_OPENPYXL = False


# デフォルト設定
DEFAULT_CONFIG = {
    "request_delay": 1.0,
    "timeout": 30,
    "headers": {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    },
    "encoding": "utf-8"
}


class WebListScraper:
    """リストとWebページを紐付けてスクレイピングするクラス"""

    def __init__(self, config: Dict = None):
        self.config = {**DEFAULT_CONFIG, **(config or {})}
        self.results = []

    def load_list_from_excel(self, file_path: str, sheet_name: str = None,
                              columns: Dict[str, int] = None) -> List[Dict]:
        """
        Excelファイルからリストを読み込み

        Args:
            file_path: Excelファイルパス
            sheet_name: シート名（省略時は最初のシート）
            columns: カラムマッピング {出力名: 列インデックス(0始まり)}

        Returns:
            レコードのリスト
        """
        if not HAS_OPENPYXL:
            raise ImportError("openpyxlがインストールされていません: pip install openpyxl")

        wb = openpyxl.load_workbook(file_path)
        ws = wb[sheet_name] if sheet_name else wb.active

        records = []
        for row_idx, row in enumerate(ws.iter_rows(min_row=2, values_only=True)):
            if not row[0]:
                continue
            record = {}
            if columns:
                for key, col_idx in columns.items():
                    record[key] = row[col_idx] if col_idx < len(row) else None
            else:
                record = {"col_" + str(i): v for i, v in enumerate(row)}
            record["_row_index"] = row_idx + 2
            records.append(record)

        return records

    def load_list_from_csv(self, file_path: str, encoding: str = "utf-8-sig") -> List[Dict]:
        """
        CSVファイルからリストを読み込み

        Args:
            file_path: CSVファイルパス
            encoding: エンコーディング

        Returns:
            レコードのリスト
        """
        records = []
        with open(file_path, 'r', encoding=encoding) as f:
            reader = csv.DictReader(f)
            for row_idx, row in enumerate(reader):
                row["_row_index"] = row_idx + 2
                records.append(row)
        return records

    def build_url(self, record: Dict, url_template: str) -> str:
        """
        URLテンプレートからURLを生成

        Args:
            record: レコード
            url_template: URLテンプレート（{id}などのプレースホルダー使用可）

        Returns:
            生成されたURL
        """
        url = url_template
        for key, value in record.items():
            placeholder = "{" + key + "}"
            if placeholder in url:
                url = url.replace(placeholder, str(value))
        return url

    def fetch_page(self, url: str) -> Optional[BeautifulSoup]:
        """
        Webページを取得

        Args:
            url: URL

        Returns:
            BeautifulSoupオブジェクト、または取得失敗時None
        """
        try:
            response = requests.get(
                url,
                headers=self.config["headers"],
                timeout=self.config["timeout"]
            )
            response.raise_for_status()
            response.encoding = self.config.get("encoding", "utf-8")
            return BeautifulSoup(response.text, 'html.parser')
        except Exception as e:
            print(f"  [ERROR] {url}: {e}")
            return None

    def extract_data(self, soup: BeautifulSoup, extractors: Dict[str, Dict]) -> Dict:
        """
        ページから情報を抽出

        Args:
            soup: BeautifulSoupオブジェクト
            extractors: 抽出設定 {
                "フィールド名": {
                    "selector": "CSSセレクタ",
                    "attr": "属性名（省略時はテキスト）",
                    "multiple": True/False（複数取得するか）,
                    "join": "区切り文字（multiple時）",
                    "regex": "正規表現（マッチ部分のみ抽出）",
                    "default": "デフォルト値"
                }
            }

        Returns:
            抽出したデータの辞書
        """
        data = {}
        for field_name, config in extractors.items():
            selector = config.get("selector")
            attr = config.get("attr")
            multiple = config.get("multiple", False)
            join_str = config.get("join", "; ")
            regex = config.get("regex")
            default = config.get("default", "")

            try:
                if multiple:
                    elements = soup.select(selector)
                    values = []
                    for el in elements:
                        if attr:
                            val = el.get(attr, "")
                        else:
                            val = el.get_text(strip=True)
                        if regex:
                            match = re.search(regex, val)
                            val = match.group(0) if match else ""
                        if val:
                            values.append(val)
                    data[field_name] = join_str.join(values) if values else default
                else:
                    element = soup.select_one(selector)
                    if element:
                        if attr:
                            val = element.get(attr, default)
                        else:
                            val = element.get_text(strip=True)
                        if regex:
                            match = re.search(regex, val)
                            val = match.group(0) if match else default
                        data[field_name] = val
                    else:
                        data[field_name] = default
            except Exception as e:
                data[field_name] = default

        return data

    def scrape(self, records: List[Dict], url_template: str,
               extractors: Dict[str, Dict], output_file: str = None,
               progress_callback: Callable = None) -> List[Dict]:
        """
        スクレイピング実行

        Args:
            records: レコードのリスト
            url_template: URLテンプレート
            extractors: 抽出設定
            output_file: 出力CSVファイル（省略時は結果をリストで返すのみ）
            progress_callback: 進捗コールバック関数

        Returns:
            結果のリスト
        """
        total = len(records)
        results = []

        print(f"スクレイピング開始: {total}件")
        print("-" * 60)

        for i, record in enumerate(records, 1):
            url = self.build_url(record, url_template)
            print(f"[{i}/{total}] {url}")

            soup = self.fetch_page(url)
            if soup:
                extracted = self.extract_data(soup, extractors)
                result = {**record, **extracted, "_url": url}
                print(f"         -> 抽出成功")
            else:
                result = {**record, "_url": url, "_error": "取得失敗"}
                print(f"         -> 取得失敗")

            results.append(result)

            if progress_callback:
                progress_callback(i, total, result)

            # 中間保存（100件ごと）
            if output_file and i % 100 == 0:
                self._save_csv(results, output_file)
                print(f"         [中間保存: {i}件]")

            # リクエスト間隔
            if i < total:
                time.sleep(self.config["request_delay"])

        # 最終保存
        if output_file:
            self._save_csv(results, output_file)

        print("-" * 60)
        success = sum(1 for r in results if "_error" not in r)
        print(f"完了: {success}/{total}件取得成功")
        if output_file:
            print(f"保存先: {output_file}")

        self.results = results
        return results

    def _save_csv(self, data: List[Dict], output_file: str):
        """CSVに保存"""
        if not data:
            return

        # 全キーを収集（順序保持）
        keys = []
        for record in data:
            for key in record.keys():
                if key not in keys:
                    keys.append(key)

        with open(output_file, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, fieldnames=keys)
            writer.writeheader()
            writer.writerows(data)


def create_extractor_from_example(soup: BeautifulSoup, example_text: str) -> Dict:
    """
    ページ内のテキスト例からCSSセレクタを推測

    Args:
        soup: BeautifulSoupオブジェクト
        example_text: 抽出したいテキストの例

    Returns:
        抽出設定
    """
    # テキストを含む要素を検索
    for element in soup.find_all(string=re.compile(re.escape(example_text))):
        parent = element.parent
        if parent:
            # クラス名があればそれを使用
            if parent.get('class'):
                selector = f"{parent.name}.{'.'.join(parent['class'])}"
            elif parent.get('id'):
                selector = f"#{parent['id']}"
            else:
                selector = parent.name
            return {"selector": selector}
    return {"selector": "", "default": ""}


# CLI実行用
if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='汎用Webスクレイピングツール')
    parser.add_argument('-c', '--config', required=True, help='設定JSONファイル')
    parser.add_argument('-o', '--output', help='出力CSVファイル')

    args = parser.parse_args()

    # 設定ファイル読み込み
    with open(args.config, 'r', encoding='utf-8') as f:
        config = json.load(f)

    scraper = WebListScraper(config.get("settings", {}))

    # リスト読み込み
    input_config = config["input"]
    if input_config["type"] == "excel":
        records = scraper.load_list_from_excel(
            input_config["file"],
            input_config.get("sheet"),
            input_config.get("columns")
        )
    elif input_config["type"] == "csv":
        records = scraper.load_list_from_csv(
            input_config["file"],
            input_config.get("encoding", "utf-8-sig")
        )

    # スクレイピング実行
    output_file = args.output or config.get("output", {}).get("file")
    scraper.scrape(
        records,
        config["url_template"],
        config["extractors"],
        output_file
    )
