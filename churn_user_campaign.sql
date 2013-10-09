use users
go


/*SPFP両方ユーザ*/
-- 2522は除く

drop table #spfp_user
select distinct a.user_id into #spfp_user
from 
	(select user_id from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] where device='sp' and mission_app!='2522') a
	left join
	(select user_id from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] where device='fp' and mission_app!='2522') b
on a.user_id=b.user_id
where b.user_id is not null
--(5317 行処理されました) (+2522場合：5805)


/*
ポイントキャンペーンのミッション実施ユーザの中で、
最近WAUで、参加アプリにログインしているか(1:churn, 0:loyal)
*/

drop table [users].[dbo].[yingzi_pointcampaign2_user_flag]
select distinct *, 1 as uu
into [users].[dbo].[yingzi_pointcampaign2_user_flag]
from(
	select [user_id], 'spfp' as device, 1 as flag
	from #spfp_user a
	where not exists(
		select 1 from (select * from [summary].[dbo].[app_all_201307] union all select * from  [summary].[dbo].[fp_app_all_201307]) b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	union all
	select [user_id], 'spfp' as device, 0 as flag
	from #spfp_user a
	where exists(
		select 1 from (select * from [summary].[dbo].[app_all_201307] union all select * from  [summary].[dbo].[fp_app_all_201307]) b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	
	union all	
	select [user_id], 'sp' as device, 1 as flag
	from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] a where device='sp' and mission_app!='2522'
	and not exists(
		select 1 from [summary].[dbo].[app_all_201307] b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	and not exists (select 1 from #spfp_user c where a.user_id=c.user_id)	
	union all
	select [user_id], 'sp' as device, 0 as flag
	from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] a where device='sp' and mission_app!='2522'
	and exists(
		select 1 from [summary].[dbo].[app_all_201307] b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	and not exists (select 1 from #spfp_user c where a.user_id=c.user_id)
	
	union all
	select [user_id], 'fp' as device, 1 as flag
	from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] a where device='fp' and mission_app!='2522'
	and not exists(
		select 1 from [summary].[dbo].[fp_app_all_201307] b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	and not exists (select 1 from #spfp_user c where a.user_id=c.user_id)
	union all
	select [user_id], 'fp' as device, 0 as flag
	from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist] a where device='fp' and mission_app!='2522'
	and exists(
		select 1 from [summary].[dbo].[fp_app_all_201307] b where date between '2013-07-23' and '2013-07-30' and [application_id] in ('99','98','1242','112','96') and a.user_id=b.user_id
	)
	and not exists (select 1 from #spfp_user c where a.user_id=c.user_id)	
)t
where NOT EXISTS
(SELECT 1 FROM [import].[dbo].[log_patrol_patrol] p WHERE t.user_id=p.user_id AND p.action=1)
and user_id != 0
--(450341 行処理されました) (+2522場合：493142)
-- select TOP 10 * from [users].[dbo].[yingzi_pointcampaign2_user_flag] 


/*
ミッションユーザの特徴量抽出（説明変数）
*/


/*①ミッション実施関連*/
select [user_id]
	, count(*) as mission_time
	, count(distinct [date]) as mission_day
	, count(distinct [mission_app]) as mission_app
	, count(distinct [mission_type]) as mission_type
	, datediff(day,cast('2013-05-30' as date),min([date])) as mission_startday
--into #mission
into [users].[dbo].[yingzi_pointcampaign2_tmp_mission]
from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist]
where mission_app!='2522'
group by [user_id]
--(452123 行処理されました)
-- select TOP 100 * from #mission

/*②ログインと休眠関連（参加アプリ、PF全体）*/
select a.[user_id]
	,a.login_day
	,a.login_app
	,a.login_time
	,b.login_day_tapp
	,b.login_app_tapp
	,b.login_time_tapp
	,isnull(c.kyumin,1) as kyumin
	,isnull(c.kyumin_tapp,1) as kyumin_tapp
--into #login
into [users].[dbo].[yingzi_pointcampaign2_tmp_login]
from(
	select distinct [user_id]
		,count(distinct [date]) as login_day
		,count(*) as login_time
		,count(distinct [application_id]) as login_app
	from(
		select * from [summary].[dbo].[app_all_201305] where date>='2013-05-30'
		union all select * from [summary].[dbo].[app_all_201306]
		union all select * from [summary].[dbo].[app_all_201307] where date<'2013-07-05'
		union all select * from [summary].[dbo].[fp_app_all_201305] where date>='2013-05-30'
		union all select * from [summary].[dbo].[fp_app_all_201306]
		union all select * from [summary].[dbo].[fp_app_all_201307] where date<'2013-07-05'	
	)t
	where exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	group by [user_id]
)a
left join
(
	select distinct [user_id]
		,count(distinct [date]) as login_day_tapp
		,count(*) as login_time_tapp
		,count(distinct [application_id]) as login_app_tapp
	from(
		select * from [summary].[dbo].[app_all_201305] where date>='2013-05-30'
		union all select * from [summary].[dbo].[app_all_201306]
		union all select * from [summary].[dbo].[app_all_201307] where date<'2013-07-05'
		union all select * from [summary].[dbo].[fp_app_all_201305] where date>='2013-05-30'
		union all select * from [summary].[dbo].[fp_app_all_201306]
		union all select * from [summary].[dbo].[fp_app_all_201307] where date<'2013-07-05'	
	)t
	where exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	and application_id in ('99','98','1242','112','96')
	group by [user_id]
)b
on a.user_id=b.user_id
left join(
	select user_id
	, 0 as kyumin
	, min((case when application_id in('99','98','1242','112','96') then 0 else 1 end)) as kyumin_tapp 
	from
	( 
		select user_id,application_id from [summary].[dbo].[app_all_201305] where date<'2013-05-30'
		union all select user_id,application_id from [summary].[dbo].[fp_app_all_201305] where date<'2013-05-30'
	)t
	where exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	group by [user_id]
)c
on a.user_id=c.user_id


/*③消費関連（参加アプリ、PF全体での消費）*/
select a.[user_id]
	,a.spend_day
	,a.spend_app
	,a.spend_time
	,a.spend_coin
	,isnull(b.spend_day_tapp,0) as spend_day_tapp
	,isnull(b.spend_app_tapp,0) as spend_app_tapp
	,isnull(b.spend_time_tapp,0) as spend_time_tapp
	,isnull(b.spend_coin_tapp,0) as spend_coin_tapp
--into #spend
into [users].[dbo].[yingzi_pointcampaign2_tmp_spend]
from(
	select [user_id]
		,count(distinct [date]) as spend_day
		,count(*) as spend_time
		,count(distinct [application_id]) as spend_app
		,sum([coin_nondeveloper]) as spend_coin
	from(
		select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201305] where date>='2013-05-30'
		union all select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201306]
		union all select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201307] where date<'2013-07-05'
	)t
	where [coin_nondeveloper]>0 and [region]='JP'
	and exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	group by [user_id]
)a
left join(
	select [user_id]
		,count(distinct [date]) as spend_day_tapp
		,count(*) as spend_time_tapp
		,count(distinct [application_id]) as spend_app_tapp
		,sum([coin_nondeveloper]) as spend_coin_tapp
	from(
		select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201305] where date>='2013-05-30'
		union all select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201306]
		union all select * from [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201307] where date<'2013-07-05'
	)t
	where [coin_nondeveloper]>0 and [region]='JP' and [application_id] in ('99','98','1242','112','96')
	and exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	group by [user_id]
)b
on a.user_id=b.user_id


/*④グリー登録経過*/
--drop table [users].[dbo].[yingzi_pointcampaign2_tmp_reg]
select a.[user_id]
      ,datediff(day, cast(b.[reg_date] as date), cast(a.[mission_startday] as date)) as reg_period
--into #reg
into [users].[dbo].[yingzi_pointcampaign2_tmp_reg]
from 
(
	select [user_id], min(date) as mission_startday from [users].[dbo].[yingzi_pointcampaign2_missionstart_uulist]
	group by [user_id]
)a
left join
(
	select distinct user_id,min(reg_date) as reg_date
	from(
		select * from [mitsuda_analytics].[dbo].[log_login_login_201305] where date>='2013-05-30'
		union all select * from [mitsuda_analytics].[dbo].[log_login_login_201306] 
		union all select * from [mitsuda_analytics].[dbo].[log_login_login_201307] where date<'2013-07-05'
	)t
	where exists(
		select 1 from [users].[dbo].[yingzi_pointcampaign2_user_flag] u where t.user_id=u.user_id 
	)
	group by user_id
)b
on a.user_id=b.user_id


/* 
特徴量統合 A：実数値
*/

--drop table [users].[dbo].[yingzi_pointcampaign2_user_feature]
select u.*
	,isnull(a.mission_time,0) as mission_time
	,isnull(a.mission_day,0) as mission_day
	,isnull(a.mission_app,0) as mission_app
	,isnull(a.mission_type,0) as mission_type
	,isnull(a.mission_startday,0) as mission_startday
	,isnull(b.login_day,0) as login_day
	,isnull(b.login_app,0) as login_app
	,isnull(b.login_time,0) as login_time
	,isnull(b.login_day_tapp,0) as login_day_tapp
	,isnull(b.login_app_tapp,0) as login_app_tapp
	,isnull(b.login_time_tapp,0) as login_time_tapp
	,isnull(b.kyumin,0) as kyumin
	,isnull(b.kyumin_tapp,0) as kyumin_tapp	
	,isnull(c.spend_day,0) as spend_day
	,isnull(c.spend_app,0) as spend_app
	,isnull(c.spend_time,0) as spend_time
	,isnull(c.spend_coin,0) as spend_coin
	,isnull(c.spend_day_tapp,0) as spend_day_tapp
	,isnull(c.spend_app_tapp,0) as spend_app_tapp
	,isnull(c.spend_time_tapp,0) as spend_time_tapp
	,isnull(c.spend_coin_tapp,0) as spend_coin_tapp
	,isnull(d.reg_period,0) as reg_period
into [users].[dbo].[yingzi_pointcampaign2_user_feature]
from [users].[dbo].[yingzi_pointcampaign2_user_flag] u
left join [users].[dbo].[yingzi_pointcampaign2_tmp_mission] a on u.user_id=a.user_id
left join [users].[dbo].[yingzi_pointcampaign2_tmp_login] b on u.user_id=b.user_id
left join [users].[dbo].[yingzi_pointcampaign2_tmp_spend] c on u.user_id=c.user_id
left join [users].[dbo].[yingzi_pointcampaign2_tmp_reg] d on u.user_id=d.user_id



/*
特徴量統合 B：ブーリアン（ダミー変数）
*/
drop table [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian]
select 
	device,
	case 
		when mission_time>0 and mission_time<=5 then 'mt1_5' 
		when mission_time>5 and mission_time<=10 then 'mt6_10'
		when mission_time>10 and mission_time<=20 then 'mt11_20'
		when mission_time>20 and mission_time<=50 then 'mt21_50'
		when mission_time>50 and mission_time<=100 then 'mt51_100'
		else 'mt_100more'
	end as mission_time,
	case
		when mission_day>0 and mission_day<=5 then 'md1_5'
		when mission_day>5 and mission_day<=10 then'md6_10'
		when mission_day>10 and mission_day<=20 then 'md11_20'
		when mission_day>20 and mission_day<=30 then 'md21_30'
		else 'md_30more'
	end as mission_day,
	case 
		when mission_startday>0 and mission_startday<=5 then 'mstd1_5'
		when mission_startday>5 and mission_startday<=10 then 'mstd6_10'	
		when mission_startday>10 and mission_startday<=20 then 'mstd11_20'	
		when mission_startday>20 and mission_startday<=30 then'mstd21_30'	
		else 'mstd_30later'	
	end as mission_startday,	
	case 
		when login_app>0 and login_app<=5 then 'la1_5'
		when login_app>5 and login_app<=10 then 'la6_10'
		when login_app>10 and login_app<=20 then 'la11_20'
		else 'la_20more'
	end as login_app,
	case 
		when login_app_tapp=1 then 'lat_1'
		when login_app_tapp=2 then 'lat_2'
		when login_app_tapp=3 then 'lat_3'
		when login_app_tapp=4 then 'lat_4'
		else 'lat_5'
	end as login_tapp,
	case
		when kyumin=1 and kyumin_tapp=1 then 'kyuPF_kyuTA'
		when kyumin=1 and kyumin_tapp=0 then 'kyuPF_actTA'
		when kyumin=0 and kyumin_tapp=1 then 'actPF_kyuTA'
		when kyumin=0 and kyumin_tapp=0 then 'actPF_actTA'
	end as kyumin,
	case 
		when spend_time>0 and spend_time_tapp>0 then 'spdPF_spdTA'
		when spend_time>0 and spend_time_tapp=0 then 'spdPF_unspdTA'
		when spend_time=0 and spend_time_tapp=0 then 'unspdPF_unspdTA'
		when spend_time=0 and spend_time_tapp>0 then 'unspdPF_spdTA'
	end as spend,
	case
		when reg_period<10 then 'reg_10'
		when reg_period>10 and reg_period<=30 then 'reg_30'
		when reg_period>30 and reg_period<=100 then 'reg_100'
		when reg_period>100 and reg_period<=500 then 'reg_500'
		else 'reg_500more'
	end as reg_period,	
	flag,
	uu
into [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian]	
from [users].[dbo].[yingzi_pointcampaign2_user_feature]


/*
分析用データ
*/

/*SPのchurn user全部と、SPのloyal user一部*/
drop table [users].[dbo].[yingzi_pointcampaign2_user_feature2]
select * 
into [users].[dbo].[yingzi_pointcampaign2_user_feature2]
from(
	select * 
	from [users].[dbo].[yingzi_pointcampaign2_user_feature]
	where flag=1 and device='sp' -- 26996
	union all
	select TOP 27000 * 
	from  [users].[dbo].[yingzi_pointcampaign2_user_feature]
	where flag=0 and device='sp' -- 27000
	order by NEWID()
)t

/*for model*/
drop table  [users].[dbo].[yingzi_pointcampaign2_user_feature2_model]
select * 
into  [users].[dbo].[yingzi_pointcampaign2_user_feature2_model]
from(
	select TOP 20000 *
	from [users].[dbo].[yingzi_pointcampaign2_user_feature2]
	where flag=1
	order by NEWID()
	union all
	select TOP 20000 *
	from [users].[dbo].[yingzi_pointcampaign2_user_feature2]
	where flag=0
	order by NEWID()
)t

/*for score*/
--drop table [users].[dbo].[yingzi_pointcampaign2_user_feature2_score]
select * 
into  [users].[dbo].[yingzi_pointcampaign2_user_feature2_score]
from [users].[dbo].[yingzi_pointcampaign2_user_feature2] a
where not exists(
	select 1 from [users].[dbo].[yingzi_pointcampaign2_user_feature2_model] b where a.user_id=b.user_id 
)


/*
予測評価
*/
--drop table #sample_sp
select * 
--into [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian_sample_sp]
from
(
	select TOP 10000 *
	from [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian]	
	where flag=1 and device='sp'
	order by NEWID()
	union all
	select TOP 10000 * 
	from [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian]	
	where flag=0 and device='sp'
	order by NEWID()
)t


drop table #predict
select case when score_0>score_1 then 0 else 1 end as predict, * 
  into #predict
  from
  (
  -- P(Di|H0)P(H0)
  select
	( 
		0.845261173398352
		*
		case
			when kyumin='actPF_actTA' then 0.9590882939 
			when kyumin='actPF_kyuTA' then 0.0176304154 
			when kyumin='kyuPF_kyuTA' then 0.0232812906 
			end
		*
		case	
			when login_app='la_20more' then 0.0416000042 
			when login_app='la1_5' then 0.3362861849 
			when login_app='la11_20' then 0.1865077801 
			when login_app='la6_10' then 0.4356060308
			end
		*
		case 
			when mission_time='mt_100more' then 0.0419835597 
			when mission_time='mt1_5' then 0.5747709832 
			when mission_time='mt11_20' then 0.1566902842 
			when mission_time='mt21_50' then 0.1191937980 
			when mission_time='mt51_100' then 0.1073613749 
			when mission_time='mt6_10' then 0.0603390525
			end
		*
		case 
			when mission_day='md_30more' then 0.2787292230 
			when mission_day='md1_5' then 0.3877193950 
			when mission_day='md11_20' then 0.1411983218
			when mission_day='md21_30' then 0.1320140077 
			when mission_day='md6_10' then 0.0178615995
			end
		*
		case 
			when mission_startday='mstd_30later' then 0.5189610376 
			when mission_startday='mstd1_5' then 0.0800553791 
			when mission_startday='mstd11_20' then 0.1550903851 
			when mission_startday='mstd21_30' then 0.1388628369 
			when mission_startday='mstd6_10' then 0.0891687618
			end
		*
		case
			when reg_period='reg_10' then 0.0104689622 
			when reg_period='reg_100' then 0.0155523855 
			when reg_period='reg_30' then 0.0070905217 
			when reg_period='reg_500' then 0.0917932268 
			when reg_period='reg_500more' then 0.8750949037
			end
		*
		case 
			when spend='spdPF_spdTA' then 0.5671786869 
			when spend='spdPF_unspdTA' then 0.1302617372 
			when spend='unspdPF_unspdTA' then 0.3025595759
			end 
	) as score_0,
	(
	  -- P(Di|H1)P(H1)
		0.154738826601648 *
		case
			when kyumin='actPF_actTA' then 0.6069399001 
			when kyumin='actPF_kyuTA' then 0.2633172608
			when kyumin='kyuPF_kyuTA' then 0.1297284886
			end
		*
		case	
			when login_app='la_20more' then 0.0883273061 
			when login_app='la1_5' then 0.3863584180 
			when login_app='la11_20' then 0.1983669135 
			when login_app='la6_10' then 0.3269330119
			end
		*
		case 
			when mission_time='mt_100more' then 0.0037024281 
			when mission_time='mt1_5' then 0.8665116813
			when mission_time='mt11_20' then 0.0560243384 
			when mission_time='mt21_50' then 0.0191866139
			when mission_time='mt51_100' then 0.0545605878
			when mission_time='mt6_10' then 0.0892600884
			end
		*
		case 
			when mission_day='md_30more' then 0.1484415361 
			when mission_day='md1_5' then 0.4066930716 
			when mission_day='md11_20' then 0.2641495896 
			when mission_day='md21_30' then 0.0914413639 
			when mission_day='md6_10' then 0.0014350497
			end
		*
		case 
			when mission_startday='mstd_30later' then 0.8104873429 
			when mission_startday='mstd1_5' then 0.0408271626 
			when mission_startday='mstd11_20' then 0.0608461053 
			when mission_startday='mstd21_30' then 0.0291458584 
			when mission_startday='mstd6_10' then 0.0572441306
			end
		*
		case
			when reg_period='reg_10' then 0.0654813157 
			when reg_period='reg_100' then 0.0477154010 
			when reg_period='reg_30' then 0.0242810401
			when reg_period='reg_500' then 0.1470208369 
			when reg_period='reg_500more' then 0.7154870559
			end
		*
		case 
			when spend='spdPF_spdTA' then 0.1991848918 
			when spend='spdPF_unspdTA' then 0.3848085644 
			when spend='unspdPF_unspdTA' then 0.4159921933
			end 
	) as score_1,
	*
	FROM [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian_sample_sp]
--  FROM [users].[dbo].[yingzi_pointcampaign2_user_feature_bayesian]
  ) t

select
SUM(case when flag=1 and predict=1 then 1 end) as TT,
SUM(case when flag=0 and predict=0 then 1 end) as FF,
SUM(case when flag=1 and predict=0 then 1 end) as TF,
SUM(case when flag=0 and predict=1 then 1 end) as FT 
from #predict
		
select (TT+FF)*1.0/(TT+TF+FT+FF) as accuracy
from
	(
	select
	SUM(case when flag=1 and predict=1 then 1 end) as TT,
	SUM(case when flag=0 and predict=0 then 1 end) as FF,
	SUM(case when flag=1 and predict=0 then 1 end) as TF,
	SUM(case when flag=0 and predict=1 then 1 end) as FT 
	from #predict
	)t
	
