#!/usr/bin/env bash

##########################################################################################################################
## Computational Connectome System (CCS)
## R-fMRI master: Xi-Nian Zuo at the Institute of Psychology, CAS. 
## Email: zuoxn@psych.ac.cn.
## Email: ting.xu@childmind.org
## 
## The analyisdirectory should be organized as follow:
## analysisdirectory
## |--sub001
## |  |--anat
## |  |    |--T1w.nii.gz
## |  |--func_1
## |  |    |--rest.nii.gz
## |  |--func_2
## |  |    |--rest.nii.gz
## |--sub002
## ...
##
## If more than one T1w and prefer to average all together, organized data as follow:
## analysisdirectory
## |--sub001
## |  |--anat
## |  |    |--T1w1.nii.gz
## |  |    |--T1w2.nii.gz
## |  |    |--T1w3.nii.gz
##########################################################################################################################


##########################################################################################################################
## PARAMETERS
###########################################################################################################################
## directory where scripts are located
scripts_dir=/data3/cnl/xli/cpac_features/ccs/code/xli/CCS
## full/path/to/site
analysisdirectory=/data3/cnl/xli/cpac_features/ccs/rerun/data
## name of anatomical scan (no extension)
anat_name=T1w
## number of anatomical scan
num_scans=10
## anat_dir_name
anat_dir_name=anat
## if do anat registration
do_anat_reg=true 
## if do anat segmentation
do_anat_seg=true
## if use freesurfer derived volumes
fs_brain=true
## Spatially Adaptive NonLocal Means (ANTs required)
sanlm_denoise=true
## standard brain
standard_head=${FSLDIR}/data/standard/MNI152_T1_2mm.nii.gz
standard_brain=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz
standard_template=${scripts_dir}/templates/MNI152_T1_3mm_brain.nii.gz
fsaverage=fsaverage5
##########################################################################################################################

## Get subjects to run
subject=$1


##########################################################################################################################
##---START OF SCRIPT----------------------------------------------------------------------------------------------------##
##########################################################################################################################

## Preprocessing anatomical images
echo "-------CCS preprocessing-------"
echo "${subject}"
echo "running ccs_01_anatpreproc ..."
echo "Skull stripping of anatomical images"
echo "-------------------------------"
use_gcut=true
mkdir -p ${analysisdirectory}/${subject}/scripts
${scripts_dir}/ccs_01_anatpreproc.sh ${subject} ${analysisdirectory} ${anat_name} ${anat_dir_name} ${sanlm_denoise} ${num_scans} ${use_gcut} ${scripts_dir}
echo  "Please check the quality of brain extraction before going to next step !!! (sometime manual edits of the brainmask.mgz are required)"
echo  "Check ${analysisdirectory}/${subject}/${anat_dir_name}/vcheck"


## Segmenting and reconstructing surfaces: anatomical images
use_gpu=false
echo "-------CCS preprocessing-------"
echo "${subject}"
echo "running ccs_01_anatsurfrecon ..."
echo "Segmenting and reconstructing cortical surfaces (may take 24 hours)"
echo "-------------------------------"
${scripts_dir}/ccs_01_anatsurfrecon.sh ${subject} ${analysisdirectory} ${anat_name} ${anat_dir_name} ${fs_brain} ${use_gpu}
tail -n  ${analysisdirectory}/${subject}/scripts/recon-all.log
echo  "Check ${analysisdirectory}/${subject}/scripts/recon-all.log"


# Registration to the template
echo "-------CCS preprocessing-------"
echo "${subject}"
echo "running ccs_02_anatregister.sh ..."
echo "Registering anatomical images to MNI152 template ..."
echo "-------------------------------"
${scripts_dir}/ccs_02_anatregister.sh ${subject} ${analysisdirectory} ${anat_dir_name}
# ## Quality assurances of spatial normalization
# reg_refine=false
# ${scripts_dir}/ccs_02_anatcheck_fnirt.sh ${analysisdirectory} ${subject_list} ${anat_dir_name} ${standard_brain} ${reg_refine}
# echo  "Check ${analysisdirectory}/${subject}/${anat_dir_name}/reg/vcheck"