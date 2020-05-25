#!/usr/bin/env python3

# Copyright 2020 Nagoya University (Wen-Chin Huang)
#  Apache 2.0  (http://www.apache.org/licenses/LICENSE-2.0)

# modified by zy22565 for english text and provided dataset("FYP_dataset")
import argparse
import codecs

from tacotron_cleaner.cleaners import custom_english_cleaners


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "transcription_path", type=str, help="path for the transcription text file"
    )
    parser.add_argument("utt2spk", type=str, help="utt2spk file for the speaker")
    parser.add_argument(
        "trans_type",
        type=str,
        default="char",
        choices=["char", "phn"],
        help="Input transcription type",
    )
    parser.add_argument("lang_tag", type=str, help="lang tag")
    parser.add_argument("spk", type=str, help="speaker name")
    parser.add_argument(
        "--transcription_path_en",
        type=str,
        default=None,
        help="path for the English transcription text file",
    )
    args = parser.parse_args()

    # clean every line in transcription file first
    transcription_dict = {}
    with codecs.open(args.transcription_path, "r", "utf-8") as fid:
        for line in fid.readlines():
            segments = line.split(" ")
            id = args.spk + "_" + segments[0]  
            content = " ".join(segments[1:])
            clean_content = custom_english_cleaners(content.rstrip())
            transcription_dict[id] = "<" + args.lang_tag + "> " + clean_content


    # read the utt2spk file and actually write
    with codecs.open(args.utt2spk, "r", "utf-8") as fid:
        for line in fid.readlines():
            segments = line.split(" ")
            id = segments[0]  # ex. E10001
            content = transcription_dict[id]

            print("%s %s" % (id, content))
