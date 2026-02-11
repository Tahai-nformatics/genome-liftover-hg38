# hg19 → hg38 Liftover & Variant Harmonization Pipeline

A robust and reproducible pipeline for harmonizing genotype data and performing genome assembly liftover (hg19/GRCh37 → hg38/GRCh38).

This pipeline standardizes variant identifiers, validates alleles against dbSNP, performs coordinate conversion using UCSC liftOver, and ensures forward-strand alignment with the reference genome.

It is designed for high-throughput genotype datasets (`.bed/.bim/.fam`) and has been validated on large-scale genomic datasets.

---

## Overview

Genome build conversion is not simply coordinate translation. Genotype datasets frequently contain:

- Non-standard variant identifiers  
- Platform-specific prefixes/suffixes  
- Reverse strand alleles  
- Outdated or incorrect RSIDs  
- Duplicate variants  
- Mismatched reference alleles  

This pipeline performs:

1. Variant ID standardization  
2. RSID reconciliation using dbSNP build 151  
3. Strand and reference allele validation  
4. Allele flipping when appropriate  
5. Removal of irreconcilable variants  
6. Coordinate liftover using UCSC liftOver  
7. Post-liftover validation using dbSNP API  

---

## 🔧 Pipeline Components

| Script | Purpose |
|--------|----------|
| `liftover_hg19.sh` | Main preprocessing and liftover pipeline |
| `2_dbsnp_api_refallele.py` | Validates positions and reference alleles via dbSNP API |
| `3_validate_variants.sh` | Final QC, allele flipping, and cleanup |

---

## ✨ Key Features

- Genome build conversion (hg19 → hg38)
- Standardizes RSID formats from:
  - GSA-rsid
  - ilmnseq_rsid
  - JHU_rsid
  - chr:pos identifiers
- Converts non-RSID identifiers to RSIDs where possible
- Removes duplicate variants
- Resolves strand flips
- Validates alleles against dbSNP API
- Drops mismatched or irreconcilable variants
- Produces forward-strand hg38-aligned PLINK files
- Generates exception and mapping logs for auditability

---

## 📦 Requirements

Ensure the following tools are installed and accessible in your `PATH`.

### Software

1. **PLINK**
   - [PLINK 1.9](https://www.cog-genomics.org/plink/1.9/)
   - [PLINK 2.0](https://www.cog-genomics.org/plink/2.0/)

2. **UCSC liftOver**
   - https://genome.ucsc.edu/cgi-bin/hgLiftOver

3. **GNU AWK**

4. **Python 3.8+**
   - Required for `2_dbsnp_api_refallele.py`
   - Uses asynchronous API calls to dbSNP

---

## 📂 Required Reference Files

Download the following reference files and place them in your `scripts/` directory (or update the paths in the pipeline).

### Reference FASTA Files

- **hg19**
  - https://hgdownload.cse.ucsc.edu/goldenpath/hg19/bigZips/

- **hg38**
  - https://hgdownload.cse.ucsc.edu/goldenpath/hg38/bigZips/

---

### dbSNP Build 151

- https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/snp151.txt.gz

Uncompress before use:

```bash
gunzip snp151.txt.gz
```
- **Chain File (hg19 → hg38)**
  - https://hgdownload.soe.ucsc.edu/gbdb/hg19/liftOver/hg19ToHg38.over.chain.gz
 
 ## 📥 Installation

Clone the repository:

```bash
git clone https://github.com/your-username/liftover-pipeline.git
cd liftover-pipeline
```

**Ensure all required tools (PLINK, liftOver, Python 3.8+, GNU AWK) are available in your PATH.**


  ## Usage
```bash
bash liftover_hg19.sh path/to/dataset/nosuffix dataset_name
```
Example:
```bash
bash liftover_hg19.sh /s3buckets/ADGCdatasets/ADGC_NHW/ACT3/CleanedGenotypes/ACT3.clean.nhw ACT3
```

If your dataset consists of:
ACT3.clean.nhw.bed
ACT3.clean.nhw.bim
ACT3.clean.nhw.fam

You must pass 
```bash
/path/to/ACT3.clean.nhw
```

## 🔍 Post-Liftover Validation (dbSNP API)

UCSC liftOver can occasionally return coordinates that look valid but do not match the expected hg19 position and/or reference allele when cross-checked against dbSNP. To reduce downstream QC issues, this pipeline includes an additional validation step using the dbSNP API.

The script `2_dbsnp_api_refallele.py` validates:

- Variant hg19 position consistency
- Reference allele consistency
- RSID ↔ coordinate mapping sanity checks (flags “weird” or ambiguous matches)

### Outputs

The validation step produces two primary log files:

#### 1) `<dataset>_exception.txt`

Contains variants that could not be validated due to API call failures (most commonly dbSNP rate limiting / transient service issues).

- **Expected:** a small number of lines
- **If large (hundreds+):** reduce request throughput and rerun the script

Common throttling controls inside `2_dbsnp_api_refallele.py`:

```python
async def main():
    batch_size = 20
```
Tip: If dbSNP is overloaded, rerunning at a lower throughput usually resolves most exceptions.

