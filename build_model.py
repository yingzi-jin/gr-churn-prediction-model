#/usr/bin/env python
# -*- coding: utf-8 -*-

#######################################################
import Orange
#import pandas
#import numpy
import pickle,csv
from myfunctions import *
#######################################################

def main():
    ## discrete value
    """
    mdata = Orange.data.Table("./data/201308d2_campaign_user_for_model.txt")
    sdata = Orange.data.Table("./data/201308d2_campaign_user_for_score.txt")
    mpath, spath = "./model/mode.dump", #"./data/score.csv"
    """
    ## continuous values★
    mdata = Orange.data.Table("./data/201308d1_campaign_user_for_model.txt") #40,000 users
    sdata = Orange.data.Table("./data/201308d1_campaign_user_for_score.txt") #13,996 users

    ## compare different learners★
    mpath, spath = "./model/model.dump", "./data/score.csv"
    classifier = build_model(data=mdata, path=mpath)

    ## scoreing
    df = score_prob(data=sdata, clf=classifier, path=spath)

    ## --------------------each model ---------------------------
    ## decision tree
    mpath, spath = "./model/model_dt.dump", "./data/score_dt.csv"
    classifier = build_model_dt(data=mdata, path=mpath)

    ## random forest
    mpath, spath = "./model/model_forest.dump", "./data/score_forest.csv"
    classifier = build_model_forest(data=mdata, path=mpath)

    ## naive bayes
    mpath, spath = "./model/model_naive.dump", "./data/score_naive.csv"
    classifier = build_model_naive(data=mdata, path=mpath)

    ## logistic regression
    mpath, spath = "./model/model_logreg.dump", "./data/score_logreg.csv"
    classifier = build_model_logreg(data=mdata, path=mpath)

    ## knn
    mpath, spath = "./model/model_knn.dump", "./data/score_knn.csv"
    classifier = build_model_knn(data=mdata, path=mpath)
    ## ------------------------------------- ---------------------------

def build_model(data,path):
    #比較
    naive = Orange.classification.bayes.NaiveLearner(name="naive")
    tree = Orange.classification.tree.TreeLearner(min_instance=5, max_depth=5, name="tree")
    forest = Orange.ensemble.forest.RandomForestLearner(base_learner=tree, trees=50, attributes=None, name="forest")
    logreg = Orange.classification.logreg.LogRegLearner(stepwise_lr=True, remove_singular=True, name="logreg")
    learners = [naive, tree, logreg, forest]

    # Print evaluation info
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=5)

    # print evaluation values
    print "Learner | CA | Brier | AUC"
    for i in range(len(learners)):
        print "%-8s %5.3f %5.3f %5.3f" % (
            learners[i].name,
            Orange.evaluation.scoring.CA(results)[i],
            Orange.evaluation.scoring.Brier_score(results)[i],
            Orange.evaluation.scoring.AUC(results)[i]
        )
    #------------------------
    #Learner | CA | Brier | AUC
    #naive    0.842 0.275 0.909
    #tree     0.878 0.205 0.889
    #logreg   0.879 0.181 0.943
    #forest   0.880 0.181 0.942
    #------------------------

    # Modelling
    # should have been choosen the best models..
    classifier = forest(data)

    # Save the Model
    # Cannot pickle.load on windows..
    pickle.dump(classifier, open(path, "w"))

    # Print the Model Info
    measure = Orange.ensemble.forest.ScoreFeature(base_learner=tree, trees=50, attributes=None)
    print "forest All importances:"
    for attr in data.domain.attributes:
        print "%15s: %6.3f" % (attr.name, measure(attr, data))
    """
    #----------------------
    forest All importances:
       mission_time:  0.081
        mission_day:  0.401
        mission_app:  0.073
       mission_type:  0.038
    mission_startday:  0.085
          login_day:  3.689
          login_app:  0.126
         login_time:  0.636
     login_day_tapp: 16.347
     login_app_tapp:  0.649
    login_time_tapp:  9.272
             kyumin:  0.135
        kyumin_tapp:  2.274
          spend_day:  0.034
          spend_app:  0.029
         spend_time:  0.158
         spend_coin:  0.240
     spend_day_tapp:  0.461
     spend_app_tapp:  0.510
    spend_time_tapp:  0.701
    spend_coin_tapp:  0.393
         reg_period:  0.086
    #----------------------
    """
    #return
    return classifier


def build_model_dt(data,path):
    # Try1: different parameters
    tree_org = Orange.classification.tree.TreeLearner(name="tree_org")
    tree_opt1 = Orange.classification.tree.TreeLearner(min_instance=5, max_depth=3,name="tree_opt1")
    tree_opt2 = Orange.classification.tree.TreeLearner(min_instances=2, m_pruning=2, same_majority_pruning=True, name='tree_opt2')
    ## cross-validation
    learners = [tree_org,tree_opt1,tree_opt2]
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=5)
    print "Learner | CA | Brier | AUC"
    for i in range(len(learners)):
        print "%-8s %5.3f %5.3f %5.3f" % (
            learners[i].name,
            Orange.evaluation.scoring.CA(results)[i],
            Orange.evaluation.scoring.Brier_score(results)[i],
            Orange.evaluation.scoring.AUC(results)[i]
        )
    """
    # Learner | CA | Brier | AUC
    # tree_org 0.852 0.249 0.874
    # tree_opt1 0.878 0.209 0.882
    # tree_opt2 0.860 0.232 0.876
    """

    ## Try2: ensemble learning
    tree = Orange.classification.tree.TreeLearner(m_pruning=2, name="tree")
    boost = Orange.ensemble.boosting.BoostedLearner(tree, name="boost")
    bagg = Orange.ensemble.bagging.BaggedLearner(tree, name="bagg")
    ## cross-validation
    learners = [tree, boost, bagg]
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=10)
    #print results
    for l, s in zip(learners, Orange.evaluation.scoring.AUC(results)):
        print "%5s: %.2f" % (l.name, s)
    """
    # tree: 0.84
    # boost: 0.84
    # bagg: 0.82
    """

    # Modelling
    classifier = tree_opt1(data)

    # Save the Model
    pickle.dump(classifier, open(path, "w"))

    # Print the Model Info
    print classifier.to_string(leaf_str="%V (%.2m: %.0M out of %.0N)")
    ## V:The predicted value at that node
    ## M: The number of instances in the majority class (that is, the class predicted by the node).
    ## N: The number of instances in the node.
    ## C: The number of instances in the given class.
    """
        login_day_tapp<=29.500
    |    login_app>122.000: 0 (1.00: 1 out of 1)
    |    login_app<=122.000
    |    |    mission_time<=115.500: 1 (0.85: 18341 out of 21512)
    |    |    mission_time>115.500: 0 (1.00: 1 out of 1)
    login_day_tapp>29.500
    |    login_day<=31.500
    |    |    spend_day_tapp<=14.500: 0 (0.56: 247 out of 438)
    |    |    spend_day_tapp>14.500: 1 (1.00: 6 out of 6)
    |    login_day>31.500
    |    |    login_time<=32.500: 1 (0.57: 8 out of 14)
    |    |    login_time>32.500: 0 (0.92: 16574 out of 18028)
    """

    print "tree leaves:",classifier.count_leaves()
    print "tree nodes:",classifier.count_nodes()
    """
    tree leaves: 7
    tree nodes: 13
    """

    # plotting dot (default:"plaintext")
    ## まず、Graphvizをインストールして、binのPathを環境設定に登録
    classifier.dot('./model/model_dt.dot',leaf_shape="box", node_shape="diamond")
    os.system("dot -Tpng ./model/model_dt.dot -o ./model/model_dt.png")

    #return
    return classifier

def build_model_forest(data,path):
    tree = Orange.classification.tree.TreeLearner(min_instance=5, max_depth=5, name="tree")
    forest = Orange.ensemble.forest.RandomForestLearner(base_learner=tree, trees=50, attributes=None, name="forest")

    ## cross-validation
    learners = [tree,forest]

    # Print evaluation info
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=5)

    # print evaluation values
    print "Learner | CA | Brier | AUC"
    for i in range(len(learners)):
        print "%-8s %5.3f %5.3f %5.3f" % (
            learners[i].name,
            Orange.evaluation.scoring.CA(results)[i],
            Orange.evaluation.scoring.Brier_score(results)[i],
            Orange.evaluation.scoring.AUC(results)[i]
        )

    t1=time.time()
    # Modelling
    # should have been choosen the best models..
    classifier = forest(data)

    # Save the Model
    pickle.dump(classifier, open(path, "w"))

    # Print the Model Info
    print "classifier:",classifier

    measure = Orange.ensemble.forest.ScoreFeature(base_learner=tree, trees=50, attributes=None)
    print "forest All importances:"
    for attr in data.domain.attributes:
        print "%15s: %6.3f" % (attr.name, measure(attr, data))

    print "Runtimes:"
    t2=time.time()
    print t2- t1

    #return
    return classifier

def build_model_naive(data,path):
    naive = Orange.classification.bayes.NaiveLearner(name="naive")

    ## cross-validation
    learners = [naive]

    # Print evaluation info
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=5)

    # print evaluation values
    print "Learner | CA | Brier | AUC"
    for i in range(len(learners)):
        print "%-8s %5.3f %5.3f %5.3f" % (
            learners[i].name,
            Orange.evaluation.scoring.CA(results)[i],
            Orange.evaluation.scoring.Brier_score(results)[i],
            Orange.evaluation.scoring.AUC(results)[i]
        )

    # Modelling
    # should have been choosen the best models..
    classifier = naive(data)

    # Save the Model
    # Cannot pickle.load on windows..
    pickle.dump(classifier, open(path, "w"))

    # Print the Model Info
    print classifier
    print "Top 5 instances:"
    for d in data[:5]:
        c = classifier(d)
        print "%s; originally %s" % (c, d.getclass())

    target=1
    print "Probabilities for %s:" % data.domain.class_var.values[target]
    for d in data[:5]:
        ps = classifier(d, Orange.classification.Classifier.GetProbabilities)
        print "%5.3f; originally %s" % (ps[target], d.getclass())

    #return
    return classifier

def build_model_logreg(data,path):
    logreg = Orange.classification.logreg.LogRegLearner(stepwise_lr=True, remove_singular=True, name="logreg")

    ## cross-validation
    learners = [logreg]

    # Print evaluation info
    results = Orange.evaluation.testing.cross_validation(learners, data, folds=5)

    # print evaluation values
    print "Learner | CA | Brier | AUC"
    for i in range(len(learners)):
        print "%-8s %5.3f %5.3f %5.3f" % (
            learners[i].name,
            Orange.evaluation.scoring.CA(results)[i],
            Orange.evaluation.scoring.Brier_score(results)[i],
            Orange.evaluation.scoring.AUC(results)[i]
        )

    t1=time.time()
    # Modelling
    classifier = logreg(data)

    # Save the Model
    pickle.dump(classifier, open(path, "w"))

    # Print the Model Info
    print "classifier:",classifier

    correct = 0.0
    for ex in data:
        if lr(ex) == ex.getclass():
            correct += 1
    print "Classification accuracy:", correct / len(data)
    print "dump:",Orange.classification.logreg.dump(classifier)

    print "Runtimes:"
    t2=time.time()
    print t2- t1

    #return
    return classifier

def build_model_knn(data,path):
    knn = Orange.classification.knn.kNNLearner(data, k=3)

    for i in range(5):
        instance = test.random_example()
        print instance.getclass(), knn(instance)



def score_prob(data, clf, path):
    score, prob = [],[]
    prob.append(["Prob(nonchurn=0)", "Prob(churn=1)"]) #

    result_type = Orange.classification.Classifier.GetBoth

    #score: [[<orange.Value 'flag'='1'>, <0.428, 0.572>], [..],...]
    for inst in data:
        score.append(clf(inst, result_type))

    # prob :  [[0.42846283316612244, 0.5715371370315552], [],...] =>出力
    for i in range(len(score)):
        prob.append([score[i][1][0], score[i][1][1]])

    writecsv = csv.writer(open(path,"wt"),lineterminator='\n')
    writecsv.writerows(prob)
    #--------------./data/score.csv
    # Prob(nonchurn=0),Prob(churn=1)
    # 0.428462833166,0.571537137032
    # 0.10837174207,0.891628265381
    # 0.203161776066,0.796838223934
    # 0.118321038783,0.881678938866
    # ...
    #---------------------------

    return
if __name__ == '__main__':
     main()
