#Make validate directory:
#mkdir -p validate
dataset_name=$1
#Copy all qced.bim files into validate directory (cp */*/qced*.bim validate/)
#cp */*/*qc.bim validate/


#Run dbsnp_refapi.py
#python3 dbsnp_api_refallele.py validate  

###Python script generates output based on mismatches - .exception.txt and dataset_name.txt###

#if [ $? -eq 0 ]; then
#    echo "Python script executed successfully. Proceeding with the rest of the script."
#else
#    echo "Python script failed. Exiting script."
#    exit 1
#fi

#Run flipallele scripts
### bash flip_alleles.sh adc15.NHW.fwd.hg38.qcallele_mismatch.txt
echo "starting script"
#for file in $PWD/validate/$DATASET_NAME/*; do
    #filename=$(basename "$file")
    #echo $filename
#dataset_name="${filename%%.*}"

echo "$dataset_name"


EXCEPTION_FILE=$dataset_name.exception.txt
POSITION_FILE=$dataset_name.txt

echo $EXCEPTION_FILE
echo $POSITION_FILE

#done
#Gather flippable rsids

awk 'BEGIN{cnuc["a"]="t"; cnuc["c"]="g"; cnuc["g"]="c"; cnuc["t"]="a"}{ bimVarId=$1; bimA2=$3; dbsnpRef=$2; if (cnuc[tolower(bimA2)]==tolower(dbsnpRef)) { print bimVarId; } else { print bimVarId >> "'"$PWD/validate/$dataset_name/$dataset_name.exclude"'"; } }' "$PWD/validate/$dataset_name/$dataset_name.allele_mismatch.txt" > "$PWD/validate/$dataset_name/$dataset_name.fliprsids.txt"





sort $PWD/validate/$dataset_name/$dataset_name.fliprsids.txt | uniq > $PWD/validate/$dataset_name/$dataset_name.sorted.fliprsids.txt

#FLIP rsids


/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/validate/$dataset_name/${dataset_name}.NHW.fwd.hg38.qc --flip $PWD/validate/$dataset_name/$dataset_name.sorted.fliprsids.txt --keep-allele-order --make-bed --out $PWD/validate/$dataset_name/$dataset_name.flipped

#ADD mismatch position and exceptions to exclude list

awk '{print $1}' $PWD/validate/$dataset_name/$EXCEPTION_FILE >> $PWD/validate/$dataset_name/$dataset_name/$dataset_name.exclude
awk '{print $1}' $PWD/validate/$dataset_name/$POSITION_FILE >> $PWD/validate/$dataset_name/$dataset_name/$dataset_name.exclude



#Remove rsids
/home/iqbalt/tools/plink-1.9/plink --bfile $PWD/validate/$dataset_name/$dataset_name.flipped --keep-allele-order --exclude $PWD/validate/$dataset_name/$dataset_name.exclude --make-bed --out $PWD/validate/$dataset_name/$dataset_name.v2


#done


