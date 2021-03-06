#!/bin/bash

run_rw=true
run_tc_gen=true
run_w2v=true
run_nc=true

ROOT=/home/


RW_JAR_FILE=$ROOT/rw/randomwalk-0.0.1-SNAPSHOT.jar
INPUT_EDGE_LIST=$ROOT/dataset/cora/cora1_edgelist.txt

METHODS=(m1)


# Random walk configs

INIT_EDGE_SIZE=0
NUM_WALKS_ARR=(80)
WALK_LENGTH_ARR=(10)
P=1.0
Q=1.0
STREAM_SIZE=5
DATASET=cora1
NUM_RUNS=1
DIRECTED=false    # tested on undirected graphs only.
SEED=1236
WALK_TYPE=secondorder
RW_DELIMITER="\\s+"    # e.g., tab-separated ("\\t"), "\\s+", or comma-separated (",").
LOG_PERIOD=1    # after what number of steps save the randomwalks output.
LOG_ERRORS=false  # Should it compute and log transition probability errors (computation intensive)   # portion of edges to be used for streaming at each step
MAX_STEPS=60117
COUNT_NUM_SCC=false
FIXED_GRAPH=false    # use same graph among different runs.

# target-context generator configs
TC_DELIMITER="\\t"    # e.g., space-separated ("\ "), or comma-separated (",").
WINDOW_SIZE=8
SKIP_SIZE=8
SELF_CONTEXT=true  # whether allows target == context pairs.
TRAIN_WITH_DELTA=false              # train only with the samples generated from new walks
FORCE_SKIP_SIZE=false                # Force to generate skipSize number of pairs
ALL_WALKS=true                      # Whether to consider all old walks and new walks of walks to generate sample from. If false it considers only a percentage of the old walks.
O=1.0                               # Percentage of new walks to draw from old walks.
COMPUTE_PER_STEP=1
START_STEP=0

TC_CONFIG_SIG="w$WINDOW_SIZE-s$SKIP_SIZE-sc$SELF_CONTEXT-twd$TRAIN_WITH_DELTA-fss$FORCE_SKIP_SIZE-aw$ALL_WALKS-o$O-cps$COMPUTE_PER_STEP"


# N2V parameters
FREEZE_AFV=false              # Freeze non-affected vertices or not?
FREEZE_AFV_FOR_M1=false
USE_CHECKPOINT=false       # whether to use checkpoints or to restart training.
NUM_CHECKPOINTS=1
TRAIN_SPLIT=1.0             # train validation split
LEARNING_RATE=0.025
EMBEDDING_SIZE=128
VOCAB_SIZE=2710            # Size of vocabulary
NEG_SAMPLE_SIZE=5
N_EPOCHS=10
BATCH_SIZE=200               # minibatch size
FREEZE_EMBEDDINGS=false     #If true, the embeddings will be frozen otherwise the contexts will be frozen.
DELIMITER="\\t"
FORCE_OFFSET=0                        # For cora and wiki datasets

# Classifier configs
LABELS_DIR=$ROOT/dataset/cora/
LABEL_FILE=cora1_labels.txt           # label file
NC_TRAIN_SPLIT=0.09
RANDOM_CLASSIFIER=false




RW_CONFIG_SIG="is$INIT_EDGE_SIZE-p$P-q$Q-ss$STREAM_SIZE-nr$NUM_RUNS-dir$DIRECTED-s$SEED-ms$MAX_STEPS-le$LOG_ERRORS-cnscc$COUNT_NUM_SCC-fg$FIXED_GRAPH"
W2V_CONFIG_SIG="ts$TRAIN_SPLIT-lr$LEARNING_RATE-es$EMBEDDING_SIZE-vs$VOCAB_SIZE-ns$NEG_SAMPLE_SIZE-ne$N_EPOCHS-bs$BATCH_SIZE-fv$FREEZE_AFV-fe$FREEZE_EMBEDDINGS-s$SEED-twd$TRAIN_WITH_DELTA-uc$USE_CHECKPOINT-ffm1$FREEZE_AFV_FOR_M1"

SCRIPT_FILE=$ROOT/rw/run_all.sh
DATE_SUFFIX=`date +%s`

SUMMARY_DIR=$ROOT/output/$DATASET/summary/summary$DATE_SUFFIX
mkdir -p $SUMMARY_DIR
cp $SCRIPT_FILE "$SUMMARY_DIR/"

if [ "$run_rw" = true ] ; then
    echo "************ Starting the random walk ************"

    trap "exit" INT

    for METHOD_TYPE in ${METHODS[*]}
    do
        for NUM_WALKS in ${NUM_WALKS_ARR[*]}
        do
            for WALK_LENGTH in ${WALK_LENGTH_ARR[*]}
            do
                printf "Run experiment for method type %s\n" $METHOD_TYPE
                printf "    Num Walks: %s\n" $NUM_WALKS
                printf "    Walk Length: %s\n" $WALK_LENGTH

                OUTPUT_DIR=$ROOT/output/$DATASET/rw/$RW_CONFIG_SIG/$METHOD_TYPE-wl$WALK_LENGTH-nw$NUM_WALKS/

                # You can customize the JVM memory size by modifying -Xms.
                # To run the script on the background: nohup sh random_walk.sh > log.txt &
                #-Xmsg
                java -Xmx100g -Xms40g -jar $RW_JAR_FILE  --cmd sca --walkLength $WALK_LENGTH --numWalks $NUM_WALKS \
                    --input $INPUT_EDGE_LIST --output $OUTPUT_DIR --nRuns $NUM_RUNS --directed $DIRECTED --p $P \
                    --q $Q --seed $SEED --d "$RW_DELIMITER" --rrType $METHOD_TYPE --save $LOG_PERIOD \
                    --logErrors $LOG_ERRORS --initEdgeSize $INIT_EDGE_SIZE --edgeStreamSize $STREAM_SIZE \
                    --maxSteps $MAX_STEPS --countScc $COUNT_NUM_SCC --fixedGraph $FIXED_GRAPH

            done
        done
    done
fi

# target-context pair generator config

PAIR_FILE="gPairs-w$WINDOW_SIZE-s$SKIP_SIZE"
VOCAB_FILE="gPairs-vocabs-w$WINDOW_SIZE-s$SKIP_SIZE"

if [ "$run_tc_gen" = true ] ; then
    echo "************ Starting the target-context generator ************"

    trap "exit" INT

    for METHOD_TYPE in ${METHODS[*]}
    do
        for NUM_WALKS in ${NUM_WALKS_ARR[*]}
        do
            for WALK_LENGTH in ${WALK_LENGTH_ARR[*]}
            do
                for RUN in $(seq 0 $(($NUM_RUNS-1)))
                do
                    INC_SEED=$(($SEED+$RUN))
                    for STEP in $(seq $START_STEP $MAX_STEPS)
                    do
                        MOD=$(( $STEP%$COMPUTE_PER_STEP ))
                        if [ "$MOD" == 0 ];then
                            printf "Run generator for method type %s\n" $METHOD_TYPE
                            printf "    Num Walks: %s\n" $NUM_WALKS
                            printf "    Walk Length: %s\n" $WALK_LENGTH
                            printf "    Run number: %s\n" $RUN
                            printf "    Step number: %s\n" $STEP

                            CONFIG=wl$WALK_LENGTH-nw$NUM_WALKS
                            EXPERIMENT_TYPE="$METHOD_TYPE-$CONFIG-$STEP-$RUN"

                            RW_FILE="sca-$EXPERIMENT_TYPE.txt"

                            if [ "$TRAIN_WITH_DELTA" == true ] && [ "$METHOD_TYPE" != "m1" ] && [ $STEP -gt 0 ]; then
                                RW_FILE="sca-$METHOD_TYPE-delta-$CONFIG-$STEP-$RUN.txt"
                            fi

                            DIR_NAME="$RW_CONFIG_SIG/$METHOD_TYPE-wl$WALK_LENGTH-nw$NUM_WALKS"
                            INPUT_EDGE_LIST=$ROOT/output/$DATASET/rw/$DIR_NAME/$RW_FILE
                            OUTPUT_DIR=$ROOT/output/$DATASET/pairs/$DIR_NAME/$TC_CONFIG_SIG/

                            java -Xmx100g -Xms40g -jar $RW_JAR_FILE  --cmd gPairs --input $INPUT_EDGE_LIST --output $OUTPUT_DIR \
                                --d "$TC_DELIMITER"  --w2vWindow $WINDOW_SIZE --w2vSkip $SKIP_SIZE \
                                --selfContext $SELF_CONTEXT --forceSkipSize $FORCE_SKIP_SIZE \
                                --allWalks $ALL_WALKS --o $O --seed $INC_SEED

                            mv "$OUTPUT_DIR$PAIR_FILE.txt" "$OUTPUT_DIR$PAIR_FILE-$EXPERIMENT_TYPE.txt"
                            mv "$OUTPUT_DIR$VOCAB_FILE.txt" "$OUTPUT_DIR$VOCAB_FILE-$EXPERIMENT_TYPE.txt"
                        fi
                    done
                done
            done
        done
    done
fi


# word2vec

# Tensorflow configurations
TENSORFLOW_BIN_DIR=$ROOT/tf/bin/
N2V_SCRIPT_DIR=$ROOT/n2v/

source $TENSORFLOW_BIN_DIR/activate tensorflow
cd $N2V_SCRIPT_DIR

if [ "$run_w2v" = true ] ; then
    echo "************ Starting word2vec ************"
    trap "exit" INT

    for METHOD_TYPE in ${METHODS[*]}
    do
        for NUM_WALKS in ${NUM_WALKS_ARR[*]}
        do
            for WALK_LENGTH in ${WALK_LENGTH_ARR[*]}
            do
                for RUN in $(seq 0 $(($NUM_RUNS-1)))
                do
                    INC_SEED=$(($SEED+$RUN))
                    for STEP in $(seq $START_STEP $MAX_STEPS)
                    do
                            MOD=$(( $STEP%$COMPUTE_PER_STEP ))
                            if [ "$MOD" == 0 ];then
                                printf "Run generator for method type %s\n" $METHOD_TYPE
                                printf "    Num Walks: %s\n" $NUM_WALKS
                                printf "    Walk Length: %s\n" $WALK_LENGTH
                                printf "    Run number: %s\n" $RUN
                                printf "    Step number: %s\n" $STEP

                                CONFIG=wl$WALK_LENGTH-nw$NUM_WALKS
                                SUFFIX="$METHOD_TYPE-$CONFIG-$STEP-$RUN"
                                FILE_SUFFIX="w$WINDOW_SIZE-s$SKIP_SIZE-$SUFFIX"
                                DIR_SUFFIX="$RW_CONFIG_SIG/$METHOD_TYPE-wl$WALK_LENGTH-nw$NUM_WALKS"
                                BASE_LOG_DIR=$ROOT/output/$DATASET/emb/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/s$STEP-r$RUN
                                INPUT_DIR=$ROOT/output/$DATASET/pairs/$DIR_SUFFIX/$TC_CONFIG_SIG/                 # input data directory
                                TRAIN_FILE="gPairs-$FILE_SUFFIX.txt"                 # train file name
                                DELTA_TRAIN_FILE="gPairs-delta-$FILE_SUFFIX.txt"
                                DEGREES_DIR=$ROOT/output/$DATASET/rw/$DIR_SUFFIX/
                                DEGREES_FILE="degrees-$SUFFIX.txt"       # node degrees file name

                                COMMAND="-m node2vec_pregen --base_log_dir $BASE_LOG_DIR --input_dir $INPUT_DIR --train_file $TRAIN_FILE --degrees_dir $DEGREES_DIR --degrees_file $DEGREES_FILE --delimiter $DELIMITER --force_offset $FORCE_OFFSET --seed $INC_SEED --train_split $TRAIN_SPLIT --learning_rate $LEARNING_RATE --embedding_size $EMBEDDING_SIZE --vocab_size $VOCAB_SIZE --neg_sample_size $NEG_SAMPLE_SIZE --n_epochs $N_EPOCHS --batch_size $BATCH_SIZE"
                                if [ "$FREEZE_EMBEDDINGS" == true ]; then
                                    COMMAND="$COMMAND  --freeze_embeddings"
                                fi

                                if [ "$NUM_CHECKPOINTS" != -1 ]; then
                                    COMMAND="$COMMAND  --num_checkpoints $NUM_CHECKPOINTS"
                                fi

                                if [ "$FREEZE_AFV" == true ] && [ $STEP -gt 0 ]; then
                                    if [ "$METHOD_TYPE" != "m1" ] || [ "$FREEZE_AFV_FOR_M1" == "true" ]; then
                                        AFFECTED_VERTICES_FILE="sca-afs-$SUFFIX.txt"     # affected vertices file name
                                        COMMAND="$COMMAND --affected_vertices_file $AFFECTED_VERTICES_FILE"
                                    fi
                                fi

                                if [ "$USE_CHECKPOINT" == true ] && [ $STEP -gt 0 ]; then
                                    COMMAND="$COMMAND --checkpoint_file model-epoch-$(($N_EPOCHS-1)) --checkpoint_dir $ROOT/output/$DATASET/emb/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/s$(($STEP-1))-r$RUN"
                                fi

                                echo $COMMAND

                                python3 $COMMAND
                        fi
                    done
                done
            done
        done
    done
fi

# Classifier

if [ "$run_nc" = true ] ; then
    echo "************ Starting the node classifier ************"

    trap "exit" INT

    for METHOD_TYPE in ${METHODS[*]}
    do
        for NUM_WALKS in ${NUM_WALKS_ARR[*]}
        do
            for WALK_LENGTH in ${WALK_LENGTH_ARR[*]}
            do
                for RUN in $(seq 0 $(($NUM_RUNS-1)))
                do
                    INC_SEED=$(($SEED+$RUN))
                    for STEP in $(seq $START_STEP $MAX_STEPS)
                    do
                        MOD=$(( $STEP%$COMPUTE_PER_STEP ))
                        if [ "$MOD" == 0 ];then
                            for EPOCH in $(seq 0 $(($N_EPOCHS-1)))
                            do
                                printf "Run generator for method type %s\n" $METHOD_TYPE
                                printf "    Num Walks: %s\n" $NUM_WALKS
                                printf "    Walk Length: %s\n" $WALK_LENGTH
                                printf "    Run number: %s\n" $RUN
                                printf "    Step number: %s\n" $STEP
                                printf "    Epoch number: %s\n" $EPOCH

                                CONFIG=wl$WALK_LENGTH-nw$NUM_WALKS
                                SUFFIX="$METHOD_TYPE-$CONFIG-$STEP-$RUN"
                                DIR_SUFFIX="$RW_CONFIG_SIG/$METHOD_TYPE-wl$WALK_LENGTH-nw$NUM_WALKS"
                                BASE_LOG_DIR=$ROOT/output/$DATASET/train/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/ts$NC_TRAIN_SPLIT/s$STEP-r$RUN
                                INPUT_DIR=$ROOT/output/$DATASET/emb/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/s$STEP-r$RUN
                                DEGREES_DIR=$ROOT/output/$DATASET/rw/$DIR_SUFFIX/                  # input data directory
                                DEGREES_FILE="degrees-$SUFFIX.txt"       # node degrees file name

                                EMB_FILE="embeddings$EPOCH.pkl"                # embeddings file name
                                COMMAND="-m ml_classifier --base_log_dir $BASE_LOG_DIR --output_index $EPOCH --input_dir $INPUT_DIR --emb_file $EMB_FILE --degrees_dir $DEGREES_DIR --degrees_file $DEGREES_FILE --delimiter $DELIMITER --force_offset $FORCE_OFFSET --seed $INC_SEED --train_split $NC_TRAIN_SPLIT --label_dir $LABELS_DIR --label_file $LABEL_FILE"

                                if [ "$COUNT_NUM_SCC" == true ]; then
                                    BSCC_VERTEX_FILE="sca-bscc-$SUFFIX.txt"
                                    COMMAND="$COMMAND --bscc_file $BSCC_VERTEX_FILE"
                                fi

                                if [ "$RANDOM_CLASSIFIER" == true ]; then
                                    COMMAND="$COMMAND  --random_classifier"
                                fi

                                echo $COMMAND

                                python3 $COMMAND
                            done
                        fi
                    done
                done
            done
        done
    done
fi

deactivate

# collect results
echo "************ Collecting results ************"
SUMMARY_SCORE_FILE="$SUMMARY_DIR/score-summary.csv"
SUMMARY_BSCC_SCORE_FILE="$SUMMARY_DIR/bscc-score-summary.csv"
SUMMARY_EPOCH_TIME="$SUMMARY_DIR/epoch-summary.csv"
SUMMARY_RW_TIME="$SUMMARY_DIR/rw-time-summary.csv"
SUMMARY_GRAPH_STAT="$SUMMARY_DIR/rw-graph-stat-summary.csv"
SUMMARY_RW_WALK="$SUMMARY_DIR/rw-walk-summary.csv"
SUMMARY_RW_STEP="$SUMMARY_DIR/rw-step-summary.csv"
SUMMARY_MAX_ERROR="$SUMMARY_DIR/rw-max-error-summary.csv"
SUMMARY_MEAN_ERROR="$SUMMARY_DIR/rw-mean-error-summary.csv"

if [ "$run_nc" = true ] ; then
    echo "method,nw,wl,run,step,epoch,train_acc,train_f1,test_acc,test_f1" >> $SUMMARY_SCORE_FILE
    echo "method,nw,wl,run,step,epoch,train_acc,train_f1,test_acc,test_f1" >> $SUMMARY_BSCC_SCORE_FILE
fi

if [ "$run_w2v" = true ] ; then
    echo "method,nw,wl,run,step,epoch,time" >> $SUMMARY_EPOCH_TIME
fi

if [ "$run_rw" = true ] ; then
    HEADER="method\tnw\twl\trun"
    GRAPH_STAT_HEADER="method\tnw\twl\trun\tstep\tn\tm\tnumSccs\tnumOtherVertices"
    for STEP in $(seq $START_STEP $MAX_STEPS)
    do
        MOD=$(( $STEP%$COMPUTE_PER_STEP ))
        if [ "$MOD" == 0 ];then
            HEADER="$HEADER\tstep$STEP"
        fi
    done

    echo -e "$HEADER" >> $SUMMARY_RW_TIME
    echo -e "$HEADER" >> $SUMMARY_RW_WALK
    echo -e "$HEADER" >> $SUMMARY_RW_STEP
    echo -e "$GRAPH_STAT_HEADER" >> $SUMMARY_GRAPH_STAT
    if [ "$LOG_ERRORS" = true ] ; then
        echo -e "$HEADER" >> $SUMMARY_MAX_ERROR
        echo -e "$HEADER" >> $SUMMARY_MEAN_ERROR
    fi

fi

trap "exit" INT

DIR_PREFIX=$ROOT/output

for METHOD_TYPE in ${METHODS[*]}
do
    for NUM_WALKS in ${NUM_WALKS_ARR[*]}
    do
        for WALK_LENGTH in ${WALK_LENGTH_ARR[*]}
        do
            CONFIG=wl$WALK_LENGTH-nw$NUM_WALKS
            DIR_SUFFIX="$RW_CONFIG_SIG/$METHOD_TYPE-wl$WALK_LENGTH-nw$NUM_WALKS"
            if [ "$run_nc" = true ] || [ "$run_w2v" = true ]; then
                for RUN in $(seq 0 $(($NUM_RUNS-1)))
                do
                    for STEP in $(seq $START_STEP $MAX_STEPS)
                    do
                        MOD=$(( $STEP%$COMPUTE_PER_STEP ))
                        if [ "$MOD" == 0 ];then
                            for EPOCH in $(seq 0 $(($N_EPOCHS-1)))
                            do
                                printf "Run generator for method type %s\n" $METHOD_TYPE
                                printf "    Num Walks: %s\n" $NUM_WALKS
                                printf "    Walk Length: %s\n" $WALK_LENGTH
                                printf "    Run number: %s\n" $RUN
                                printf "    Step number: %s\n" $STEP
                                printf "    Epoch number: %s\n" $EPOCH


                                SUFFIX="$METHOD_TYPE-$CONFIG-$STEP-$RUN"

                                if [ "$run_nc" = true ]; then
                                    SCORE_INPUT_DIR="$DIR_PREFIX/$DATASET/train/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/ts$NC_TRAIN_SPLIT/s$STEP-r$RUN"
                                    SCORE_FILE="$SCORE_INPUT_DIR/scores$EPOCH.txt"
                                    SCORE=$(<$SCORE_FILE)
                                    SUMMARY="$METHOD_TYPE,$NUM_WALKS,$WALK_LENGTH,$RUN,$STEP,$EPOCH,$SCORE"
                                    echo "$SUMMARY" >> $SUMMARY_SCORE_FILE

                                    BSCC_SCORE_FILE="$SCORE_INPUT_DIR/bscc-scores$EPOCH.txt"
                                    BSCC_SCORE=$(<$BSCC_SCORE_FILE)
                                    BSCC_SUMMARY="$METHOD_TYPE,$NUM_WALKS,$WALK_LENGTH,$RUN,$STEP,$EPOCH,$BSCC_SCORE"
                                    echo "$BSCC_SUMMARY" >> $SUMMARY_BSCC_SCORE_FILE
                                fi

                                if [ "$run_w2v" = true ]; then
                                    EPOCH_INPUT_DIR="$DIR_PREFIX/$DATASET/emb/$DIR_SUFFIX/$TC_CONFIG_SIG/$W2V_CONFIG_SIG/s$STEP-r$RUN"
                                    EPOCH_FILE="$EPOCH_INPUT_DIR/epoch_time.txt"

                                    EPOCH_PREFIX="$METHOD_TYPE,$NUM_WALKS,$WALK_LENGTH,$RUN,$STEP"
                                    while IFS='' read -r line || [[ -n "$line" ]]; do
                                        echo "$EPOCH_PREFIX,$line" >> $SUMMARY_EPOCH_TIME
                                    done < "$EPOCH_FILE"
                                fi
                            done
                        fi
                    done
                done
            fi

            if [ "$run_rw" = true ]; then
                SUMMARY_PREFIX="$METHOD_TYPE\t$NUM_WALKS\t$WALK_LENGTH"
                STEPS_FILE="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-steps-to-compute-wl$WALK_LENGTH-nw$NUM_WALKS.txt"
                WALK_FILE="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-walkers-to-compute-wl$WALK_LENGTH-nw$NUM_WALKS.txt"
                TIME_FILE="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-time-to-compute-wl$WALK_LENGTH-nw$NUM_WALKS.txt"
                STAT_FILE_PREFIX="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-graphstats-wl$WALK_LENGTH-nw$NUM_WALKS"

                if [ "$LOG_ERRORS" = true ] ; then
                    MAX_ERROR_FILE="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-max-errors-wl$WALK_LENGTH-nw$NUM_WALKS.txt"
                    MEAN_ERROR_FILE="$DIR_PREFIX/$DATASET/rw/$DIR_SUFFIX/$METHOD_TYPE-mean-errors-wl$WALK_LENGTH-nw$NUM_WALKS.txt"
                    counter=0
                    while IFS='' read -r line || [[ -n "$line" ]]; do
                        echo -e "$SUMMARY_PREFIX\t$counter\t$line" >> $SUMMARY_MAX_ERROR
                        counter=$((counter+1))
                    done < "$MAX_ERROR_FILE"
                    counter=0
                    while IFS='' read -r line || [[ -n "$line" ]]; do
                        echo -e "$SUMMARY_PREFIX\t$counter\t$line" >> $SUMMARY_MEAN_ERROR
                        counter=$((counter+1))
                    done < "$MEAN_ERROR_FILE"
                fi

                counter=0
                while IFS='' read -r line || [[ -n "$line" ]]; do
                    echo -e "$SUMMARY_PREFIX\t$counter\t$line" >> $SUMMARY_RW_STEP
                    counter=$((counter+1))
                done < "$STEPS_FILE"
                counter=0
                while IFS='' read -r line || [[ -n "$line" ]]; do
                    echo -e "$SUMMARY_PREFIX\t$counter\t$line" >> $SUMMARY_RW_WALK
                    counter=$((counter+1))
                done < "$WALK_FILE"
                counter=0
                while IFS='' read -r line || [[ -n "$line" ]]; do
                    echo -e "$SUMMARY_PREFIX\t$counter\t$line" >> $SUMMARY_RW_TIME
                    counter=$((counter+1))
                done < "$TIME_FILE"

                for RUN in $(seq 0 $(($NUM_RUNS-1)))
                do
                    STAT_PREFIX="$SUMMARY_PREFIX\t$RUN"
                    counter=0
                    while IFS='' read -r line || [[ -n "$line" ]]; do
                        echo -e "$STAT_PREFIX\t$counter\t$line" >> $SUMMARY_GRAPH_STAT
                        counter=$((counter+1))
                    done < "$STAT_FILE_PREFIX-$RUN.txt"
                done
            fi
        done
    done
done

# run with nohup and write the output in a file named log.txt.
mv $ROOT/output/log.txt $SUMMARY_DIR/
echo "Experiment Finished!"

echo "Summary dir: $SUMMARY_DIR"