
/*
ユーザ抽出(churn or loyal)
今月のアクティビティで、3か月後のchurnを予測する
*/
SELECT distinct user_id
INTO #users
FROM [mitsuda_analytics].[dbo].[log_login_login_201303] a
WHERE region='JP' and right(user_id,3)=100 and right(user_id,3)=101
and NOT EXISTS
(SELECT 1 FROM [import].[dbo].[log_patrol_patrol] b WHERE a.user_id=b.user_id AND b.action=1)
--36410

/*
churn判別
*/
SELECT *
INTO [users].[dbo].[yingzi_tmp_user_flag]
FROM(
	SELECT [user_id], 0 as flag
	FROM #users a
	WHERE EXISTS(SELECT 1 FROM [summary].[dbo].[sp_web_all_201306] b WHERE a.user_id=b.user_id)
	UNION ALL
	SELECT [user_id], 1 as flag
	FROM #users c
	WHERE NOT EXISTS(SELECT 1 FROM [summary].[dbo].[sp_web_all_201306] d WHERE c.user_id=d.user_id)
)t
--select flag,COUNT(distinct user_id) from #users_flag group by flag
-- churn:1541, loyal:2104

/*
ユーザのデータ
*/

--drop table [users].[dbo].[yingzi_tmp_raw_login_data]
-- ログインデータ
SELECT *
INTO [users].[dbo].[yingzi_tmp_raw_login_data]
FROM (
	SELECT * FROM [mitsuda_analytics].[dbo].[log_login_login_201303] WHERE region='JP'
	UNION ALL
	SELECT * FROM [mitsuda_analytics].[dbo].[log_login_login_201304] WHERE region='JP'	
	UNION ALL
	SELECT * FROM [mitsuda_analytics].[dbo].[log_login_login_201305] WHERE region='JP'
) t
WHERE EXISTS(
	SELECT 1 FROM #users u WHERE t.user_id=u.user_id
)
--(795855 行処理されました)


-- GAME play
SELECT *
INTO [users].[dbo].[yingzi_tmp_raw_game_data]
FROM (
	SELECT * FROM [summary].[dbo].[app_all_201303] WHERE category = 2
	UNION ALL
	SELECT * FROM [summary].[dbo].[app_all_201304] WHERE category = 2
	UNION ALL
	SELECT * FROM [summary].[dbo].[app_all_201305] WHERE category = 2
) t	
WHERE EXISTS(
	SELECT 1 FROM #users u WHERE t.user_id=u.user_id
)
--(268892 行処理されました)

-- 消費データ
SELECT *
INTO [users].[dbo].[yingzi_tmp_raw_spend_data]
FROM(
	SELECT * FROM [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201303] WHERE region='JP' and type in(-2010)
	UNION ALL
	SELECT * FROM [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201304] WHERE region='JP' and type in(-2010)
	UNION ALL
	SELECT * FROM [mitsuda_analytics].[dbo].[log_platform_ggp_spend_spend_201305] WHERE region='JP' and type in(-2010)

) t  
WHERE EXISTS(
	SELECT 1 FROM #users u WHERE t.user_id=u.user_id
) 
--(34382 行処理されました)

-- アクションデータ
--drop table [users].[dbo].[yingzi_tmp_raw_action_data]
SELECT *
INTO [users].[dbo].[yingzi_tmp_raw_action_data]
FROM(
	SELECT 'appsnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_appsnet_201303] a1 WHERE EXISTS(SELECT 1 FROM #users u WHERE a1.user_id=u.user_id)
	UNION ALL 
	SELECT 'appsnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_appsnet_201304] a2 WHERE EXISTS(SELECT 1 FROM #users u WHERE a2.user_id=u.user_id) 
	UNION ALL 
	SELECT 'appsnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_appsnet_201305] a3 WHERE EXISTS(SELECT 1 FROM #users u WHERE a3.user_id=u.user_id) 		
	UNION ALL 
	SELECT 'gamesnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_gamesnet_201303] b1 WHERE EXISTS(SELECT 1 FROM #users u WHERE b1.user_id=u.user_id) 
	UNION ALL 
	SELECT 'gamesnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_gamesnet_201304] b2 WHERE EXISTS(SELECT 1 FROM #users u WHERE b2.user_id=u.user_id)
	UNION ALL 	
	SELECT 'gamesnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_gamesnet_201305] b3 WHERE EXISTS(SELECT 1 FROM #users u WHERE b3.user_id=u.user_id)
	UNION ALL 
	SELECT 'pfnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_pfnet_201303] c1 WHERE EXISTS(SELECT 1 FROM #users u WHERE c1.user_id=u.user_id) 
	UNION ALL 
	SELECT 'pfnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_pfnet_201304] c2 WHERE EXISTS(SELECT 1 FROM #users u WHERE c2.user_id=u.user_id)
	UNION ALL 	
	SELECT 'pfnet' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_pfnet_201305] c3 WHERE EXISTS(SELECT 1 FROM #users u WHERE c3.user_id=u.user_id)
	UNION ALL 
	SELECT 'tgames' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_tgames_201303] d1 WHERE EXISTS(SELECT 1 FROM #users u WHERE d1.user_id=u.user_id) 
	UNION ALL 
	SELECT 'tgames' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_tgames_201304] d2 WHERE EXISTS(SELECT 1 FROM #users u WHERE d2.user_id=u.user_id)
	UNION ALL 	
	SELECT 'tgames' as domain,[date],[user_id],[action],[query_string] FROM [mitsuda_analytics].[dbo].[log_access_view_tgames_201305] d3 WHERE EXISTS(SELECT 1 FROM #users u WHERE d3.user_id=u.user_id)  
)t
--(863544 行処理されました)

/* 
特徴量抽出

P:属性:age,sex,device,grade
L:ログイン:reg_date,login_days, (active_times, active_days, total_online_time, login_times)
M:消費:spent_coin, spent_time, spent_app_num, spent_mean
G:ゲーム:app_num, app_cnt, app_play_days
S:SNS:sns_login, sns_login_time, sns_login_day, link_num
A:アクション:action_num, action_cnt
D:ドメイン:domain_num, domain_cnt

*/  

/**/
SELECT a.user_id
	,a.flag
	,b.P_age
	,b.P_sex
	,b.P_grade
	,b.P_is_invite
	,b.P_phone_carrier
	,b.S_link_num
	,b.S_link_made
	,b.L_reg_period
	,b.L_login_days
	,b.D_service_id_num
	,b.D_service_id_cnt	
	,isnull(c.G_app_num,0) as G_app_num
	,isnull(c.G_app_cnt,0) as G_app_cnt
	,isnull(c.G_app_play_days,0) as G_app_play_days
	,isnull(d.M_spent_coin,0) as M_spent_coin
	,isnull(d.M_spent_time,0) as M_spent_time
	,isnull(d.M_spent_app_num,0) as M_spent_app_num
	,isnull(e.A_action_num,0) as A_action_num
	,isnull(e.A_action_cnt,0) as A_action_cnt
	,isnull(e.A_domain_num,0) as A_domain_num
	,isnull(e.A_domain_cnt,0) as A_domain_cnt
	,isnull(e.A_qs_num,0) as A_qs_num
	,isnull(e.A_qs_cnt,0) as A_qs_cnt
--INTO #user_data_raw
FROM [users].[dbo].[yingzi_tmp_user_flag] a
LEFT JOIN
(
	SELECT [user_id] as user_id
		,MAX([age]) as P_age
		,MAX([sex]) as P_sex
		,MAX([grade]) as P_grade
		,MAX(is_invite) as P_is_invite
		,MAX([phone_carrier]) as P_phone_carrier
		,MIN([link_num]) as S_link_num
		,MAX([link_num])-MIN([link_num]) as S_link_made
		--,MAX([reg_date]) as L_reg_date
		--,MAX(date) as L_last_access
		,DATEDIFF(day,MAX([reg_date]),MAX(date)) as L_reg_period
		,COUNT(distinct cast(date as date)) as L_login_days
		,COUNT(distinct [service_id]) as D_service_id_num
		,COUNT([service_id]) as D_service_id_cnt
	FROM [users].[dbo].[yingzi_tmp_raw_login_data]
	GROUP BY [user_id]
)b
ON a.user_id=b.user_id  
LEFT JOIN
(
	SELECT [user_id]
		,COUNT(distinct application_id) as G_app_num
		,COUNT(*) as G_app_cnt
		,COUNT(distinct cast(date as date)) as G_app_play_days
	FROM [users].[dbo].[yingzi_tmp_raw_game_data]
	GROUP BY [user_id]
)c
ON a.user_id=c.user_id
LEFT JOIN
(
	SELECT [user_id] 
		,SUM([coin_nondeveloper]) as M_spent_coin
		,COUNT(*) as M_spent_time
		,COUNT(distinct application_id) as M_spent_app_num
	FROM [users].[dbo].[yingzi_tmp_raw_spend_data]
	GROUP BY [user_id]
)d
ON a.user_id=d.user_id
LEFT JOIN
(
	SELECT [user_id]
		,COUNT(DISTINCT [action]) as A_action_num
		,COUNT([action]) as A_action_cnt
		,COUNT(DISTINCT [query_string]) as A_qs_num
		,COUNT([query_string]) as A_qs_cnt
		,COUNT(DISTINCT [domain]) as A_domain_num
		,COUNT([domain]) as A_domain_cnt
	FROM [users].[dbo].[yingzi_tmp_raw_action_data]
	GROUP BY [user_id]	
)e
ON a.user_id=e.user_id

