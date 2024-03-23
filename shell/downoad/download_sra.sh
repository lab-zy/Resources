# Author: penglingwei
# 2024.03.23
# 新版本NCBI不再支持ascp的方式下载测序数据，本脚本使用ascp和prefetch下载测序数据数据，优先使用ascp下载(速度更快)
# 使用方法：
# sh 01.download_sra experiment_accession
# 输出结果：
raw/
├── SRX10487851
    ├── SRR14117411_1.fastq.gz
    ├── SRR14117411_2.fastq.gz
    └── SRX10487851.tsv


# input
experiment_accession=$1 ; wd=raw
keyfile=/share/home/yzwl_zhouy/software/aspera-3.7.4/etc/asperaweb_id_dsa.openssh

# output
outfolder=${wd}/${experiment_accession} ; mkdir -p ${outfolder}
tsv=${outfolder}/${experiment_accession}.tsv
url="https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${experiment_accession}&result=read_run&fields=run_accession,fastq_md5,fastq_aspera&format=tsv&download=true&limit=0"

echo "=>=>=>${experiment_accession}"
date

echo ">>>step1：从ebi中下载${experiment_accession}的详细信息" 
wget -c ${url} -O ${tsv} 
if [ -s "${tsv}" ] ; then 
  status=1 
else
  echo ">>>无法获得ebi中${experiment_accession}的样本信息" 
  status=0
fi

single () {
  fq=${outfolder}/${run}.fastq.gz
  num=0
  while [ "${status}" == 1 ]
  do
    num=$((num+1))
    if [ ${num} -gt 5 ] ; then echo ">>>${run}下载失败, 已多次尝试" ; status=0 ; break ; fi
    if [ ! -f ${fq} ] || [ `md5sum ${fq} | awk '{print $1}'` != "${fastq_md5}" ] ; then
      echo ">>>第${num}次下载" 
      ascp -vQT -l 500M -P33001 -k 1 -i ${keyfile} era-fasp@${fastq_aspera} ${fq}
    else
      echo ">>>ascp成功下载${experiment_accession}数据, 第${num}次成功"
      break
    fi
  done

}

pair () {
  fastq_md51=`echo ${fastq_md5} | awk -F ";" '{print $1}'`
  fastq_md52=`echo ${fastq_md5} | awk -F ";" '{print $2}'`
  fastq_aspera1=`echo ${fastq_aspera} | awk -F ";" '{print $1}'`
  fastq_aspera2=`echo ${fastq_aspera} | awk -F ";" '{print $2}'`
  fq1=${outfolder}/${run}_1.fastq.gz
  fq2=${outfolder}/${run}_2.fastq.gz
  num=0
  while [ "${status}" == 1 ]
  do
    num=$((num+1))
    if [ ${num} -gt 5 ] ; then echo ">>>${run}下载失败, 已多次尝试" ; status=0 ; break ; fi
    if [ ! -f ${fq1} ] || [ ! -f ${fq2} ] || [ `md5sum ${fq1} | awk '{print $1}'` != "${fastq_md51}" ] || [ `md5sum ${fq2} | awk '{print $1}'` != "${fastq_md52}" ] ; then
      echo ">>>第${num}次下载" 
      ascp -vQT -l 500M -P33001 -k 1 -i ${keyfile} era-fasp@${fastq_aspera1} ${fq1}
      ascp -vQT -l 500M -P33001 -k 1 -i ${keyfile} era-fasp@${fastq_aspera2} ${fq2}
    else
      echo ">>>ascp成功下载${experiment_accession}数据, 第${num}次成功"
      break
    fi
  done
}

awk 'NR>1' ${tsv} | while IFS=$'\t' read -r run fastq_md5 fastq_aspera
do
  echo ">>>step2：检测fastq_aspera是否有效" 
  if [ "${fastq_aspera}" == "" ] ; then echo ">>>fastq_aspera无效" ; status=0 ; fi
  end=`echo ${fastq_aspera} | awk -F ";" '{print NF}'`
  if [ "${end}" == 1 ] ; then
    single
  else
    pair
  fi
done

if [ "${status}" == 0 ] ; then
  echo ">>>step2：prefetch开始下载数据" 
  prefetch ${experiment_accession} -O ${outfolder} && fastq-dump --split-3 `ls ${outfolder}/*/*sra` -O ${outfolder} && echo ">>>prefetch成功下载${experiment_accession}数据"
fi
date
