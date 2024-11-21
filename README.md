# ***LIFTOVER AND VARIANT PROCESSING PIPELINE***

This repository contains a comprehensive liftover and variant processing pipeline designed to process genotype data, update RSIDs, and perform genomic coordinate conversions from one reference genome to another (e.g., hg19 to hg38). 

The script leverages **PLINK** (v1.9 and v2), UCSC's **liftOver** tool, and custom **AWK** scripts to ensure accurate and streamlined processing of genomic data.

---

## **Features**
- Supports liftover of coordinates between genome assemblies (e.g., hg18 → hg38).
- Standardizes RSIDS syntax from various genotyping chips (GSA-rsid, ilmnseq_rsid, JHU_rsid, etc)
- Converts non-RSID variant identifiers to RSIDs where possible.
- Removes duplicate variants and updates RSIDs using reference files.
- Ensures genomic alignment by flipping alleles to match the reference genome.
- Generates exclusion lists for unresolvable or mismatched variants.

---

## **Requirements**

Ensure the following tools and files are installed or downloaded and accessible in your system's `PATH`:

### **Tools**:
1. **PLINK**:
   - [PLINK 1.9](https://www.cog-genomics.org/plink/1.9/)
   - [PLINK 2](https://www.cog-genomics.org/plink/2.0/)
2. **UCSC liftOver Tool**:
   - [liftOver](http://genome.ucsc.edu/cgi-bin/hgLiftOver)
   - Required chain files for liftover (e.g., `hg19ToHg38.over.chain.gz`).
3. **AWK**:
   - GNU AWK for custom text processing.

### **Reference File**:
- **snp151.txt.gz**:
  - Download from the UCSC Genome Browser database:
    [hg19 database directory](ftp://hgdownload.cse.ucsc.edu/goldenPath/hg19/database/)
  - Description:
    - The file contains a dump of the UCSC genome annotation database for the February 2009 human genome assembly (hg19/GRCh37).
    - Ensure you uncompress it using `gunzip` before usage:
      ```bash
      gunzip snp151.txt.gz
      ```

---

## **Usage**

### **1. Clone the Repository**

```bash
git clone https://github.com/your-username/liftover-pipeline.git
cd liftover-pipeline
