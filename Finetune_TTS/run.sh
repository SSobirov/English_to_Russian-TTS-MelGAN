#!/bin/bash

# Copyright 2020 Nagoya University (Wen-Chin Huang)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)
# Modified by zy22565 for FYP_Dataset
. ./path.sh || exit 1;
. ./cmd.sh || exit 1;

# general configuration
backend=pytorch
stage=-1
stop_stage=100
ngpu=1       # number of gpus ("0" uses cpu, otherwise use gpu)
nj=10        # numebr of parallel jobs
dumpdir=dump # directory to dump full features
verbose=0    # verbose option (if set > 0, get more log)
N=0          # number of minibatches to be used (mainly for debugging). "0" uses all minibatches.
seed=1       # random seed number
resume=""    # the snapshot path to resume (if set empty, no effect)

# feature extraction related
fs=16000      # sampling frequency
fmax=7600     # maximum frequency
fmin=80       # minimum frequency
n_mels=80     # number of mel basis
n_fft=1024    # number of fft points
n_shift=256   # number of shift points
win_length="" # window length

# silence part trimming related
trim_threshold=25 # (in decibels)
trim_win_length=1024
trim_shift_length=256
trim_min_silence=0.01

trans_type=  # char or phn

# config files
train_config=conf/train_pytorch_transformer+spkemb.yaml

# pretrained model related
pretrained_model_dir=downloads  
                                
pretrained_model_name=         
                               
finetuned_model_name=        

# dataset configuration
db_root=downloads/FYP_Dataset
eval_db_root=downloads/FYP_Dataset    
list_dir=local/lists
spk=SEF1 
lang=Eng

# vc configuration                                        
trgspk=                                         
tts_model_dir=                                  
                                            

# exp tag
tag=""  

. utils/parse_options.sh || exit 1;


set -e
set -u
set -o pipefail

org_set=${spk}
train_set=${spk}_train
dev_set=${spk}_dev

################################################

# TTS training (finetuning)

if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    echo "stage 0: Data preparation"

    if [ ! -e ${db_root} ]; then
        echo "${db_root} not found."
        echo "cd ${db_root}; ./run.sh --stop_stage -1; cd -"
        exit 1;
    fi

    local/data_prep_task2.sh ${db_root} data/${org_set} ${lang} ${spk} ${trans_type}
    utils/data/resample_data_dir.sh ${fs} data/${org_set}
    utils/fix_data_dir.sh data/${org_set}
    utils/validate_data_dir.sh --no-feats data/${org_set}
fi

feat_tr_dir=${dumpdir}/${train_set}; mkdir -p ${feat_tr_dir}
feat_dt_dir=${dumpdir}/${dev_set}; mkdir -p ${feat_dt_dir}
if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    echo "stage 1: Feature Generation"

    # Trim silence parts at the begining and the end of audio
    mkdir -p exp/trim_silence/${org_set}/figs  # avoid error
    trim_silence.sh --cmd "${train_cmd}" \
        --fs ${fs} \
        --win_length ${trim_win_length} \
        --shift_length ${trim_shift_length} \
        --threshold ${trim_threshold} \
        --min_silence ${trim_min_silence} \
        data/${org_set} \
        exp/trim_silence/${org_set}

    # Generate the fbank features; by default 80-dimensional fbanks on each frame
    fbankdir=fbank
    make_fbank.sh --cmd "${train_cmd}" --nj ${nj} \
        --fs ${fs} \
        --fmax "${fmax}" \
        --fmin "${fmin}" \
        --n_fft ${n_fft} \
        --n_shift ${n_shift} \
        --win_length "${win_length}" \
        --n_mels ${n_mels} \
        data/${org_set} \
        exp/make_fbank/${org_set} \
        ${fbankdir}

    # make train/dev set according to lists
    lang_char=$(echo ${spk} | head -c 2 | tail -c 1)
    sed -e "s/^/${spk}_/" ${list_dir}/${lang_char}_train_list.txt > data/${org_set}/${lang_char}_train_list.txt
    sed -e "s/^/${spk}_/" ${list_dir}/${lang_char}_dev_list.txt > data/${org_set}/${lang_char}_dev_list.txt
    utils/subset_data_dir.sh --utt-list data/${org_set}/${lang_char}_train_list.txt data/${org_set} data/${train_set}
    utils/subset_data_dir.sh --utt-list data/${org_set}/${lang_char}_dev_list.txt data/${org_set} data/${dev_set}

    # use pretrained model cmvn
    cmvn=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "cmvn.ark" | head -n 1)

    # dump features for training
    dump.sh --cmd "$train_cmd" --nj ${nj} --do_delta false \
        data/${train_set}/feats.scp ${cmvn} exp/dump_feats/${train_set} ${feat_tr_dir}
    dump.sh --cmd "$train_cmd" --nj ${nj} --do_delta false \
        data/${dev_set}/feats.scp ${cmvn} exp/dump_feats/${dev_set} ${feat_dt_dir}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    echo "stage 2: Dictionary and Json Data Preparation"

    dict=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "*_units.txt" | head -n 1)
    nlsyms=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "*_non_lang_syms.txt" | head -n 1)
    echo "dictionary: ${dict}"

    # make json labels using pretrained model dict
    data2json.sh --feat ${feat_tr_dir}/feats.scp --nlsyms "${nlsyms}" --trans_type ${trans_type} \
         data/${train_set} ${dict} > ${feat_tr_dir}/data.json
    data2json.sh --feat ${feat_dt_dir}/feats.scp --nlsyms "${nlsyms}" --trans_type ${trans_type} \
         data/${dev_set} ${dict} > ${feat_dt_dir}/data.json
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    echo "stage 3: x-vector extraction"
    # Make MFCCs and compute the energy-based VAD for each dataset
    mfccdir=mfcc
    vaddir=mfcc
    for name in ${train_set} ${dev_set}; do
        utils/copy_data_dir.sh data/${name} data/${name}_mfcc_16k
        utils/data/resample_data_dir.sh 16000 data/${name}_mfcc_16k
        steps/make_mfcc.sh \
            --write-utt2num-frames true \
            --mfcc-config conf/mfcc.conf \
            --nj 1 --cmd "$train_cmd" \
            data/${name}_mfcc_16k exp/make_mfcc_16k ${mfccdir}
        utils/fix_data_dir.sh data/${name}_mfcc_16k
        sid/compute_vad_decision.sh --nj 1 --cmd "$train_cmd" \
            data/${name}_mfcc_16k exp/make_vad ${vaddir}
        utils/fix_data_dir.sh data/${name}_mfcc_16k
    done

    # Check pretrained model existence
    nnet_dir=exp/xvector_nnet_1a
    if [ ! -e ${nnet_dir} ]; then
        echo "X-vector model does not exist. Download pre-trained model."
        wget http://kaldi-asr.org/models/8/0008_sitw_v2_1a.tar.gz
        tar xvf 0008_sitw_v2_1a.tar.gz
        mv 0008_sitw_v2_1a/exp/xvector_nnet_1a exp
        rm -rf 0008_sitw_v2_1a.tar.gz 0008_sitw_v2_1a
    fi
    # Extract x-vector
    for name in ${train_set} ${dev_set}; do
        sid/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 4G" --nj 1 \
            ${nnet_dir} data/${name}_mfcc_16k \
            ${nnet_dir}/xvectors_${name}
    done
    # Update json
    for name in ${train_set} ${dev_set}; do
        local/update_json.sh ${dumpdir}/${name}/data.json ${nnet_dir}/xvectors_${name}/xvector.scp
    done
fi

# add pretrained model info in config
pretrained_model_path=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "snapshot*" | head -n 1)
if [ -z "$pretrained_model_path" ]; then
    pretrained_model_path=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "model.loss*" | head -n 1)
fi
if [ -z "$pretrained_model_path" ]; then
    pretrained_model_path=$(find ${pretrained_model_dir}/${pretrained_model_name} -name "model.last*" | head -n 1)
fi
if [ -z "$pretrained_model_path" ]; then
    echo "Cannot find pretrained model"
    exit 1
fi

train_config="$(change_yaml.py -a pretrained-model="${pretrained_model_path}" \
    -o "conf/$(basename "${train_config}" .yaml).${pretrained_model_name}.yaml" "${train_config}")"

if [ -z ${tag} ]; then
    expname=${train_set}_${backend}_$(basename ${train_config%.*})
else
    expname=${train_set}_${backend}_${tag}
fi
expdir=exp/${expname}
if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    echo "stage 4: Text-to-speech model fine-tuning"

    mkdir -p ${expdir}
    
    # copy x-vector into expdir
    # empty the scp file
    xvec_dir=exp/xvector_nnet_1a/xvectors_${train_set}
    cp ${xvec_dir}/spk_xvector.ark ${expdir}
    sed "s~${xvec_dir}/~~" ${xvec_dir}/spk_xvector.scp > ${expdir}/spk_xvector.scp

    tr_json=${feat_tr_dir}/data.json
    dt_json=${feat_dt_dir}/data.json
    ${cuda_cmd} --gpu ${ngpu} ${expdir}/train.log \
        tts_train.py \
           --backend ${backend} \
           --ngpu ${ngpu} \
           --minibatches ${N} \
           --outdir ${expdir}/results \
           --tensorboard-dir tensorboard/${expname} \
           --verbose ${verbose} \
           --seed ${seed} \
           --resume ${resume} \
           --train-json ${tr_json} \
           --valid-json ${dt_json} \
           --config ${train_config}
fi