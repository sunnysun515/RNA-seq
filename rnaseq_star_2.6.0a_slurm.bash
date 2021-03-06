#!/bin/bash                  
                                                                                                                                                                   
#SBATCH --job-name=RNAseqStar
##SBATCH --nodes=1
##SBATCH --cpus-per-task=1
#SBATCH --mem=100GB
##SBATCH --gres=gpu:1
##SBATCH --partition=gpu4_medium
#SBATCH --partition=cpu_long
#SBATCH --error=/gpfs/data/proteomics/projects/Sunny/ribsome/err_out/%x_%j.err
#SBATCH --output=/gpfs/data/proteomics/projects/Sunny/ribsome/err_out/%x_%j.out
##SBATCH --dependency=afterany:job_id                                        

module load star/2.6.0a

# reads file                                                                                                                                                                                    
fq_r1=$1.fastq.gz
#fq_r2=$1_R2_001.fastq.gz.cleaned.fastq.gz

# folder of fastq files                                                                                                                                                                         
dir=/gpfs/data/proteomics/projects/Sunny/ribsome/mcf7/fastq
genomedir=/gpfs/data/proteomics/projects/Sunny/genome/human/hg38_star
outputdir=${dir}/star_out/$1

# go to the output directory
mkdir ${dir}/star_out                                                                                                                                                                    
mkdir $outputdir
cd $outputdir

# Splice junction detection                                                                                                                                                                     
STAR \
--genomeDir ${genomedir} \
--readFilesIn ${dir}/${fq_r1} \
--runThreadN 8 \
--outFilterMultimapScoreRange 1 \
--outFilterMultimapNmax 20 \
--outFilterMismatchNmax 10 \
--alignIntronMax 500000 \
--alignMatesGapMax 1000000 \
--sjdbScore 2 \
--alignSJDBoverhangMin 1 \
--genomeLoad NoSharedMemory \
--outFilterMatchNminOverLread 0.33 \
--outFilterScoreMinOverLread 0.33 \
--sjdbOverhang 100 \
--outSAMstrandField intronMotif \
--outSAMtype None \
--outSAMmode None \
--readFilesCommand zcat \

# INTERMEDIATE INDEX GENERATION                                                                                                                                                                 
STAR \
--runMode genomeGenerate \
--genomeDir ${outputdir} \
--genomeFastaFiles ${genomedir}/hg38.fa \
--sjdbOverhang 100 \
--runThreadN 16 \
--sjdbFileChrStartEnd ${outputdir}/SJ.out.tab

# Alignment 2ND PASS                                                                                                                                                                                    
STAR \
--genomeDir $outputdir \
--readFilesIn ${dir}/${fq_r1} \
--runThreadN 8 \
--outFilterMultimapScoreRange 1 \
--outFilterMultimapNmax 20 \
--outFilterMismatchNmax 10 \
--alignIntronMax 500000 \
--alignMatesGapMax 1000000 \
--sjdbScore 2 \
--alignSJDBoverhangMin 1 \
--genomeLoad NoSharedMemory \
--limitBAMsortRAM 0 \
--readFilesCommand zcat \
--outFilterMatchNminOverLread 0.33 \
--outFilterScoreMinOverLread 0.33 \
--sjdbOverhang 100 \
--outSAMstrandField intronMotif \
--outSAMattributes NH HI NM MD AS XS \
--outSAMunmapped Within \
--outSAMtype BAM Unsorted \
--outSAMheaderHD @HD VN:1.4


module load samtools/1.3

#sort bam file                     
samtools sort -n ${outputdir}/Aligned.out.bam > ${outputdir}/Aligned.out.bam.sort.bam

# htseq          
samtools view -F 4 ${outputdir}/Aligned.out.bam.sort.bam | \
htseq-count \
-i ID \
-t gene \
-s no \
-m intersection-nonempty \
- ${gtf} \
> ${outputdir}/$1_count.txt

