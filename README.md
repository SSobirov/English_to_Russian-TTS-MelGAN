# English_to_Russian-TTS-MelGAN
Email: zy22565@nottingham.edu.cn or shohinzya@gmail.com

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/drive/1QCBZ9AV9l467kdlKwsVIyrvU9WauOvuC) The project's demonstration can be run on Google Colab. 

# Project idea and its aim
This project aims to perform English to Russian Voice conversion. The project proposes a framework for performing English to Russian voice conversion. The framework consists from finetuned Transformer based TTS model ( target speaker is SEF1 in FYP_Dataset folder) and MelGAN vocoder.
The dissertation paper of this project can be sent upon request.

# Usage
Open Google Colab https://colab.research.google.com/ and upload the .ipynb file from the corresponding folders on this Github repo. For example, if you want to start finetuning stage upload "FinetuneTTS.ipynb" from "Finetune_TTS" to google colab. If you want to try the demo, just click the "Open in Colab" icon above. For more details for each stage check Readme.txt file in each folder. If Readme.txt file is missing, then just upload .ipynb file to Google Colab and folow instruction in the opened Google Colab notebook.

# Folder and their contents
1) Finetune_TTS contains files and codes to finetune pretrained TTS model
2) finetuned folder is already finetuned model
3) FYP_Dataset is the dataset for finetuning TTS model
4) Prepare_dataset is the files and codes for preparing "FYP_Dataset"
5) tool folder contains the binary files that are used during the training process of the TTS model
6) Training_TTS contains files and codes to Train TTS model
7) TTS+MelGAN is the demo
8) converted samples folder contains original voice, converted to russian voice and english voice(just to check the similarity
9) pretrained_tts_model folder contains TTS model trained on English and Russian Datasets
If you have problems with the contents of the "pretrained_tts_model", please download it from the link.
Link: https://drive.google.com/open?id=167QyW-NLurvhYzIX8rnzlPbTtSDJpKK_
