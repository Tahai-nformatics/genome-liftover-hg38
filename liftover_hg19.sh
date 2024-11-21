#!/bin/bash

"""
Liftover hg19 .bed/.bim/.fam dataset to hg38 via plink2 & plink1.9
usage bash liftover_hg19.sh /path/to/dataset/example_dataset[without .bed/.bim/.fam extension] example_dataset
"""
filepath=$1
datasetname=$2
dataset=$(basename "$filepath")

mkdir -p $PWD/$datasetname
mkdir -p $PWD/$datasetname/$dataset
echo "dataset is $dataset"

plink2 --bfile $filepath --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/genotypes
## 1. set A2 as genomic REF using genomic reference (NOTE: this does NOT actually guarantee all A2s will be set)
plink2 --bfile $filepath --fa /home/iqbalt/Projects/ADGC_lifeover/hg19.fa --ref-from-fa force --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa

#2a Convert non rsids syntax rsids to rsids (GSA-rsids, ilumina-rsids)
awk 'BEGIN{FS=OFS="\t"} {filtered = $2; gsub(/^.*rs/, "rs", filtered); print $2, filtered}' $PWD/$datasetname/$dataset/genotypes_fa.bim > $PWD/$datasetname/$dataset/update_list.txt

##Update datasets rsids
plink2 --bfile $PWD/$datasetname/$dataset/genotypes_fa --update-name $PWD/$datasetname/$dataset/update_list.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_fa_syntaxupdate1_rm_dups
plink2 --bfile $PWD/$datasetname/$dataset/genotypes --update-name $PWD/$datasetname/$dataset/update_list.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_syntaxupdate1_rm_dups
##Remove Duplicate rsids after syntax update
#plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_fa --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_fa_syntaxupdate1_rm_dups
#plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_syntaxupdate1_rm_dups

#2b Convert non rsids syntax () to rsids (rsid-hg18_Coor, rsid-MultiHit, etc. ) Split by _ or - and check if either split contains rs - assing rsid
awk 'BEGIN {OFS = "\t"} {n = split($2, parts, /[_-]/); if (n >= 2 && (index(parts[1], "rs") == 1 || index(parts[2], "rs") == 1)) {old = $2; new = (index(parts[1], "rs") == 1) ? parts[1] : parts[2]; print old, new}}' $PWD/$datasetname/$dataset/updated_genotypes_fa_syntaxupdate1_rm_dups.bim > $PWD/$datasetname/$dataset/update_list2.txt
##Update dataset rsids
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_fa_syntaxupdate1_rm_dups --update-name $PWD/$datasetname/$dataset/update_list2.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate2_rm_dups
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_syntaxupdate1_rm_dups --update-name $PWD/$datasetname/$dataset/update_list2.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_gsadups_removed_syntaxupdate2_rm_dups


##For rsids.1 etc, strip away the .:
awk '{original=$2; if ($2 ~ /^rs[0-9]+\./) sub(/\..*/, "", $2); print original, $2}' $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate2_rm_dups.bim > $PWD/$datasetname/$dataset/update_list3.txt

#
##3a Formatting / Syntax - Remove Duplicate rsids after syntax update
#
#
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate2_rm_dups --update-name $PWD/$datasetname/$dataset/update_list3.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate3_rm_dups

plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_gsadups_removed_syntaxupdate2_rm_dups --update-name $PWD/$datasetname/$dataset/update_list3.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_gsadups_syntaxupdate3_rm_dups

#3b Convert XY chr to X chr - will be used for chr:position match as snp151.txt does not have chr XY
awk 'BEGIN{FS=OFS="\t"} $1=="XY" {$1="X"} {print}' $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate3_rm_dups.bim > $PWD/$datasetname/$dataset/updated2_genotypes_fa.bim
awk 'BEGIN{FS=OFS="\t"} $1=="XY" {$1="X"} {print}' $PWD/$datasetname/$dataset/updated_genotypes_gsadups_syntaxupdate3_rm_dups.bim > $PWD/$datasetname/$dataset/updated2_genotypes.bim
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_gsadups_removed_syntaxupdate2_rm_dups --update-map $PWD/$datasetname/$dataset/updated2_genotypes.bim --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated2_genotypes_mapped1
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_fa_gsadups_syntaxupdate2_rm_dups --update-map $PWD/$datasetname/$dataset/updated2_genotypes_fa.bim --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/updated2_genotypes_fa_mapped1



#3c Add Chr:Pos to files for Chr:pos findings
paste -d'\t' $PWD/$datasetname/$dataset/updated2_genotypes_fa_mapped1.bim <(awk '{print $1":"$4}' $PWD/$datasetname/$dataset/updated2_genotypes_fa_mapped1.bim) > $PWD/$datasetname/$dataset/genotypes_fa_chrpos.bim
#paste -d'\t' $PWD/$datasetname/$dataset/updated2_genotypes_mapped1.bim <(awk '{print $1":"$4}' $PWD/$datasetname/$dataset/updated2_genotypes_mapped1.bim) > $PWD/$datasetname/$dataset/genotypes_fa_chrpos.bim


#4 - Split workflow into 2 datasets - rsids for rsid-rsid match and chr:pos variants for chr:pos match.
awk '$2 !~ /^rs/' $PWD/$datasetname/$dataset/genotypes_fa_chrpos.bim > $PWD/$datasetname/$dataset/genotypes_fa_norsids_chrpos.bim
awk '$2 ~ /^rs/' $PWD/$datasetname/$dataset/genotypes_fa_chrpos.bim > $PWD/$datasetname/$dataset/genotypes_fa_rsids_chrpos.bim


#5 Sort Files and merge by rsid and by chr_pos
sort -t $'\t' -k2,2 $PWD/$datasetname/$dataset/genotypes_fa_rsids_chrpos.bim > $PWD/$datasetname/$dataset/sorted_genotypes_fa_rsids_chrpos.bim
sort -t$'\t' -k7,7  $PWD/$datasetname/$dataset/genotypes_fa_norsids_chrpos.bim > $PWD/$datasetname/$dataset/sorted_genotypes_fa_norsids_chrpos.bim
if [ ! -f "$PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt" ]; then
    LC_ALL=C join -t$'\t' -1 2 -2 5 -a 1 -e "EMPTY" -o 1.{1..7} 2.{1..27}  $PWD/$datasetname/$dataset/sorted_genotypes_fa_rsids_chrpos.bim /home/iqbalt/scripts/liftover/snp151_chr_pos_rsidsorted4.txt >  $PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt
fi

if [ ! -f "$PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt" ]; then
    LC_ALL=C join -t$'\t' -1 7 -2 27 -a 1 -e "EMPTY" -o 1.{1..7} 2.{1..27}  $PWD/$datasetname/$dataset/sorted_genotypes_fa_norsids_chrpos.bim /home/iqbalt/scripts/liftover/snp151_chr_pos_rsidsorted2.txt >  $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt
fi


#6 Create exclusion_list.txt: List of variants which were not found based on rsids - chr_pos match:
awk '$8 == "EMPTY" { print $2 }' $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt > $PWD/$datasetname/$dataset/exclusion_list.txt
awk '$8 == "EMPTY" { print $2 }' $PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt >> $PWD/$datasetname/$dataset/exclusion_list.txt


###ADD non positional match to exclusion list


#### Remove non matched/empty
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/updated2_genotypes_fa_mapped1 --keep-allele-order --exclude $PWD/$datasetname/$dataset/exclusion_list.txt --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty


#######7 Try to keep as many duplicate nonrsids as possible. Duplicate nonrsids - With one match allele matching ref --> keep. Exclude all duplicate nonrsids. They map to multiple rsids so not sure
##Gather unique non-rsids
cut -f 2,12 $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt | grep -v "EMPTY" | awk '{if (seen[$1] == 1) { unique[$1] = 0; } else if (seen[$1] == 0) { unique[$1] = $0; seen[$1] = 1; }} END { for (key in unique) { if (unique[key] != 0) { print unique[key]; }}}' > $PWD/$datasetname/$dataset/update_list_nonrsids.txt
### Gather non rsid syntax duplicate variants -- to check if only 1 "hit" remains after duplicate refallele match vs dbsnp.
cut -f 2,12 $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt | grep -v "EMPTY" | cut -f 1 | uniq -d > $PWD/$datasetname/$dataset/remaining_duplicate_nonrsids.txt
grep -F -f $PWD/$datasetname/$dataset/remaining_duplicate_nonrsids.txt $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt > $PWD/$datasetname/$dataset/matching_variants_duplicates.txt

### Gather all duplicates where Alleles match
if [ -f "$PWD/$datasetname/$dataset/matching_variants_duplicates.txt" ]; then
    awk '{bimVarId=$7; dbsnpVarId=$34; bimA2=$6; dbsnpRef=$16; if ((bimVarId==dbsnpVarId) && (bimA2==dbsnpRef)) print $2"\t"$12}' $PWD/$datasetname/$dataset/matching_variants_duplicates.txt > $PWD/$datasetname/$dataset/matching_variants_duplicates_withref.txt
fi

###All duplicates where alleles match - Gather unique after filtering for allele match
if [ -f "$PWD/$datasetname/$dataset/matching_variants_duplicates_withref.txt" ]; then
    awk '{if (seen[$1] == 1) { unique[$1] = 0; } else if (seen[$1] == 0) { unique[$1] = $0; seen[$1] = 1; }} END { for (key in unique) { if (unique[key] != 0) { print unique[key]; }}}' $PWD/$datasetname/$dataset/matching_variants_duplicates_withref.txt >> $PWD/$datasetname/$dataset/update_list_nonrsids.txt
    sort $PWD/$datasetname/$dataset/update_list_nonrsids.txt > uniq -u  > $PWD/$datasetname/$dataset/update_list_nonrsids_uniq.txt

    awk '{if (seen[$1] == 1) { unique[$1] = 0; } else if (seen[$1] == 0) { unique[$1] = $0; seen[$1] = 1; }} END { for (key in unique) { if (unique[key] != 0) { print unique[key]; }}}' $PWD/$datasetname/$dataset/matching_variants_duplicates_withref.txt > $PWD/$datasetname/$dataset/matching_variants_duplicates_withoneref.txt
### Merge all duplicates remaining_duplicate_nonrsids.txt with matched duplicates matching_variants_duplicates_withoneref - drop the rest
fi
touch $PWD/$datasetname/$dataset/exclusion_list2.txt
if [ -f "$PWD/$datasetname/$dataset/matching_variants_duplicates_withoneref.txt" ]; then
    comm -13 <(sort $PWD/$datasetname/$dataset/matching_variants_duplicates_withoneref.txt) <(sort $PWD/$datasetname/$dataset/remaining_duplicate_nonrsids.txt) > $PWD/$datasetname/$dataset/exclusion_list2.txt
fi


# 8 Exclude duplicate nonrsids
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty --keep-allele-order --exclude $PWD/$datasetname/$dataset/exclusion_list2.txt --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups

#### Update name of non-rsids variants with match to rsids
plink2 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups --update-name $PWD/$datasetname/$dataset/update_list_nonrsids_uniq.txt --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v2
plink2 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v2 --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v3
plink2 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v3 --update-name $PWD/$datasetname/$dataset/update_list_nonrsids.txt --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v3_nodups


#plink2 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups --update-name $PWD/$datasetname/$dataset/update_list_nonrsids.txt --rm-dup force-first --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_updated


#9a Flip variants
awk '{bimVarId=$2; rsid=$18; dbsnpVarId=$(12); bimPos=$4; dbSnpPos=$(11); bimA2=$6; dbsnpRef=$16; if ((dbSnpPos==bimPos) && (bimVarId==dbsnpVarId) && bimA2!=dbsnpRef) print}' $PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt | awk 'BEGIN{cnuc["a"]="t"; cnuc["c"]="g"; cnuc["g"]="c"; cnuc["t"]="a"}{ bimVarId=$2; bimA2=$6; bimA1=$5; rsid=$18; dbsnpRef=$16; if ( ( (cnuc[tolower(bimA2)]==tolower(dbsnpRef)) || (cnuc[tolower(bimA1)]==tolower(dbsnpRef)) )) print bimVarId; }' > $PWD/$datasetname/$dataset/rsids_to_be_flipped.txt
awk '{bimVarId=$7; rsid=$18; dbsnpVarId=$34; bimPos=$4; dbSnpPos=$11; bimA2=$6; dbsnpRef=$16; if ((dbSnpPos==bimPos) && (bimVarId==dbsnpVarId) && (bimA2!=dbsnpRef)) print}' $PWD/$datasetname/$dataset/merged_nonrsids_chrpos_genotypes_snp151.txt | awk 'BEGIN{cnuc["a"]="t"; cnuc["c"]="g"; cnuc["g"]="c"; cnuc["t"]="a"}{ bimVarId=$2; bimA2=$6; bimA1=$5; rsid=$18; dbsnpRef=$16; if ( ( (cnuc[tolower(bimA2)]==tolower(dbsnpRef)) || (cnuc[tolower(bimA1)]==tolower(dbsnpRef)) )) print bimVarId; }' >> $PWD/$datasetname/$dataset/rsids_to_be_flipped.txt


uniq $PWD/$datasetname/$dataset/rsids_to_be_flipped.txt > $PWD/$datasetname/$dataset/rsids_to_be_flipped_uniq.txt
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_droppedempty_nodups_v3_nodups --flip $PWD/$datasetname/$dataset/rsids_to_be_flipped_uniq.txt --make-bed --out $PWD/$datasetname/$dataset/updated_genotypes_fa_mapped_flipped
## 9b set A2 to genomic REF again (now for the variants that were complemented/'flipped')
plink2 --bfile $PWD/$datasetname/$dataset/updated_genotypes_fa_mapped_flipped --fa /home/iqbalt/Projects/ADGC_lifeover/hg19.fa --ref-from-fa force --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa


####Some datasets have chr0 rsids but they map to a rsid in dbsnp so update dataset to proper mapping

## some rsids-rsids are found in different position depending on haplotype so keep only unique

#rsids: Already joined based on rsid-rsid. Check positions, allele match.
#*#*Deprecated since Liftovertool validates positions and allele match #*#*
#grep -v "chr6_" $PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt | awk '$6!=$(4+6+6) || $4!=$(11) || $2!=$12' | cut -f 3 | sort -u > $PWD/$datasetname/$dataset/variant_ids_to_be_dropped.txt
#awk 'BEGIN{OFS="\t"} NR==FNR{if($1==0) map[$2]=$2"\t"$9; next} $2 in map{sub(/^chr/, "", $2); print map[$2], $9, $11}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa.bim merged_rsids_chrpos_genotypes_snp151.txt > $PWD/$datasetname/$dataset/mapping.txt
awk 'BEGIN{OFS="\t"} NR==FNR{if($1==0) map[$2]=$2$9$11; next} $2 in map{sub(/^chr/, "", $2); if(map[$2] == "") print "No match for", $2; else print map[$2], $9, $11}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa.bim $PWD/$datasetname/$dataset/merged_rsids_chrpos_genotypes_snp151.txt > $PWD/$datasetname/$dataset/mapping.txt
#update unique chr0 mapping rsids
awk '!seen[$1]++' $PWD/$datasetname/$dataset/mapping.txt | awk 'BEGIN {OFS="\t"} {gsub(/^chr/, "", $2); if ($2 ~ /_/) {split($2, parts, "_"); $2 = parts[1]}} 1' > $PWD/$datasetname/$dataset/mapping_unique.txt


## If chr is not numeric or X or Y or MT, remove it
awk 'BEGIN {OFS="\t"} {gsub(/^chr/, "", $2); if ($2 ~ /^[0-9XYMT]+$/) print}' $PWD/$datasetname/$dataset/mapping_unique.txt > $PWD/$datasetname/$dataset/mapping_unique_filtered.txt
awk '{print $1"\t"$2}' $PWD/$datasetname/$dataset/mapping_unique_filtered.txt > $PWD/$datasetname/$dataset/mapping_chr.txt
awk '{print $1"\t"$3}' $PWD/$datasetname/$dataset/mapping_unique_filtered.txt > $PWD/$datasetname/$dataset/mapping_position.txt



/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa --keep-allele-order --update-chr $PWD/$datasetname/$dataset/mapping_chr.txt --update-map $PWD/$datasetname/$dataset/mapping_position.txt --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa

#plink-1.9 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa --keep-allele-order --output-chr chrM --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa_formatted

awk 'BEGIN{FS=OFS="\t"} $1=="23" {$1="X"} $1=="24" {$1="Y"} $1=="25" {$1="XY"} $1=="26" {$1="MT"} {print}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa.bim > $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa_formatted.bim


## 8. Lift to hg38
### 8.1. convert current hg18 bim to bed for lifting
awk 'BEGIN{FS="\t";OFS="\t"}{print "chr"$1, ($4-1), $4, FNR, $0}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa_formatted.bim > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.bed
### 8.2. lift hg18 bed to hg38
/home/iqbalt/tools/liftOver -bedPlus=3 -tab $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.bed /home/iqbalt/Projects/ADGC_lifeover/hg19ToHg38.over.chain.gz $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.unlifted.bed
### 8.3. get reference alleles for every lifted position and compare with the hg18 a2/ref
awk '{print $1":"($2+1)"-"$3}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed.regions
samtools faidx /home/iqbalt/Projects/ADGC_lifeover/hg38.fa -r $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed.regions | grep -v "^>" > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed.regions.ref_alleles
paste $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed <( cat $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.bed.regions.ref_alleles | tr '[:lower:]' '[:upper:]' ) > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.bed
### 8.4. create a final lifted bed file with matching hg38 ref and hg18 ref
#### additionally check for cross-chromosome lifting
awk '{ liftedChrNum=$1; gsub(/^chr/,"",liftedChrNum); origChrNum=$5; gsub(/^chr/,"", origChrNum); if (liftedChrNum!=origChrNum) next; hg18ref=$10; hg38ref=$11; if (hg18ref==hg38ref) print; }' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.bed > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.matching_a2_and_ref.bed
### 8.5. create variantId, hg38 positions file for use with plink --update-map
awk '{varId=$6; hg38pos=$3; print varId, hg38pos}' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.matching_a2_and_ref.bed > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.matching_a2_and_ref.bed.updated_positions
### 8.6. create a list of variants to be dropped from the current hg18 bim (unlifted variants + non-matching hg18/hg38 ref alleles)
awk '{ if (ARGIND==1) keep[$4]=1; else { if ((keep[FNR]+0)!=1) print $2; }  }' $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.matching_a2_and_ref.bed $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa_formatted.bim > $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.to_be_dropped_after_liftover
### 8.7. drop variants from the current hg18 filesetcat
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_mapped_fa --keep-allele-order --exclude $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.to_be_dropped_after_liftover --make-bed --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped_droppedAfterLiftover
### 8.8. make a new/updated hg38 plink fileset
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped_droppedAfterLiftover --update-map $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped.bim.hg18.lifted_to_hg38.with_genomic_ref.matching_a2_and_ref.bed.updated_positions --make-bed --keep-allele-order --out $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped_droppedAfterLiftover_hg38
##Convert chrX to chr23, chrY to 24, ChrXY to 25 as per PLINK standards

/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped_droppedAfterLiftover_hg38 --make-bed --keep-allele-order --out $PWD/$datasetname/$dataset/$datasetname.NHW.fwd.hg38.qc



#plink-1.9 --bfile $PWD/$datasetname/$dataset/genotypes_fa_flipped_fa_dropped_droppedAfterLiftover_hg38 --update-chr /mnt/analysis/users/taha.iqbal/to_share/adgc_liftover/NHW/mapping.txt --keep-allele-order --make-bed --out $PWD/$datasetname/$dataset/$datasetname.NHW.fwd.hg38.qc
