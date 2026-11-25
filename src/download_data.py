"""Download the UCI Online Retail dataset (Dec 2010 – Dec 2011, UK-based online retailer).

Original source: Chen, D. (2015). Online Retail [Dataset]. UCI Machine Learning Repository.
https://archive.ics.uci.edu/dataset/352/online+retail
The CSV copy below is the one published with "Spark: The Definitive Guide" (Databricks).
"""
from pathlib import Path
from urllib.request import urlretrieve

URL = ("https://raw.githubusercontent.com/databricks/Spark-The-Definitive-Guide/"
       "master/data/retail-data/all/online-retail-dataset.csv")
DEST = Path(__file__).resolve().parents[1] / "data" / "online_retail.csv"

if __name__ == "__main__":
    DEST.parent.mkdir(exist_ok=True)
    if DEST.exists():
        print(f"already downloaded: {DEST}")
    else:
        print("downloading ~45 MB ...")
        urlretrieve(URL, DEST)
        print(f"saved to {DEST}")
