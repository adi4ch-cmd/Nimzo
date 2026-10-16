# Nimzo: 7 games aur Task rewards ke proposed rules

**Haalat: sirf proposal. Abhi approve ya deploy nahi hua.** Yeh sheet APK ke maujooda UI/reference ko dekh kar banayi gayi hai. Is file ko badalne se live game, wallet ya reward enable nahi hota.

## Aapko kis cheez ka faisla karna hai

1. Neeche diye coin limits aur winning chances qabool hain ya values badalni hain.
2. Fruit Party, Grady Pro, Bigetar aur Lucky Wheel mein wazeh **No Win** result add karna hai. Bigetar mein iski chance **71.1637%** aur Lucky Wheel mein **69.03%** hai; high multipliers rakhne ka yeh trade-off hai.
3. Football ka gross payout reference ke 2.5x/6x/2.5x se **2.25x/4.5x/2.25x** karna hai.
4. Teen Patti yahan **A/B/C outcome game** hoga; traditional multiplayer poker nahi. Football **virtual game** hoga; kisi real match ya live sports feed ka result nahi.
5. Daily Task rewards **1,000 + 500 + 500 = 2,000 coins** rakhne hain.

## Reference ko seedha enable kyun nahi kar sakte

HTML apne rules ko demo kehta hai. Lucky Wheel ke aath purane sectors sab 2x ya usse zyada dete hain: har spin mein guaranteed profit hoga. Bigetar ke displayed multipliers par sab outcomes cover karke bhi guaranteed profit ban sakta hai. Football ke 2.5x/6x/2.5x payouts mein bhi sab sides cover karne ki cost guaranteed payout se kam ho sakti hai.

Isliye reference ka random demo code live coins ke saath chalana theek implementation nahi hoga. Neeche explicit probabilities, No Win result aur Football ke adjusted payouts propose kiye hain. Yeh faisle abhi aapki review ke liye hain.

## Sab games ke mushtarka rules

- **Gross payout mein asal stake shamil hai.** 1,000 coins ki 5x winning bet: pehle 1,000 debit, phir 5,000 credit; net faida 4,000. Loss par payout zero.
- Tamam amounts integer coins mein. Bet 100-coin increments mein hogi. Grady aur Slot ki minimum bet 5,000; baqi ki 100.
- Ek option ya spin par maximum **50,000 coins**. Multi-option round mein tamam options mila kar maximum **100,000 coins**. UI ke purane 1M/10M chips ko approved server limits ke mutabiq update karna hoga.
- Fruit Party, Grady aur Bigetar mein maximum 6 distinct options; Teen Patti aur Football mein maximum 3. Sirf selected result ki bet payout leti hai.
- Round games: **12 seconds betting**, maximum **3 seconds settlement**, phir **3 seconds result display**. Deadline, round ID aur rules version server se aayenge. Accepted bet badli ya cancel nahi ki ja sakti.
- Slot/Wheel: user ka har Spin ek alag request; pehla pending Spin settle hone se pehle naya debit nahi.
- Active, authenticated account aur allowed room membership zaroori. Room game permissions backend par enforce hongi. Disabled/suspended room/account par nayi bets reject hongi.
- Client sirf request aur animation dikhayega. Debit, random outcome, payout aur settlement **server-authoritative** honge. Client ki clock, random result ya displayed balance authority nahi hoga.
- Neeche har chance 1,000,000 possible server draws mein integer weight se defined hai. Account, balance, previous losses, device ya admin kisi individual ki odds chupke se nahi badlenge.
- **RTP:** Slot/Wheel ka long-run average 90%; multi-option games mein har individual bet ka expected return takreeban 90%. Yeh har player/session ke liye 90% refund ya winning guarantee nahi.

## Har game ki exact chance aur payout

### 1. Fruit Party Jackpot

| Result | Winning chance | Gross payout |
|---|---:|---:|
| Orange | 18% | 5x |
| Kiwi | 18% | 5x |
| Apple | 18% | 5x |
| Avocado | 2% | 45x |
| Watermelon | 18% | 5x |
| Lemon | 3.6% | 25x |
| Mango | 6% | 15x |
| Pomegranate | 9% | 10x |
| No Win | 7.4% | 0x |

### 2. Grady Pro

| Result | Winning chance | Gross payout |
|---|---:|---:|
| Tomato | 18% | 5x |
| Mushroom | 18% | 5x |
| Onion | 18% | 5x |
| Shaljam | 18% | 5x |
| Meat | 9% | 10x |
| Fish | 6% | 15x |
| Jinga | 3.6% | 25x |
| Chicken | 2% | 45x |
| No Win | 7.4% | 0x |

Pizza ek alag winning outcome nahi: chosen chip pehle 4 vegetables par lagti hai. 5,000 chip par total 20,000 debit hoga. Mixed Meat isi tarah 4 meat options par chip lagata hai. Group selection se pehle total cost dikhani hogi; 6-option aur round limits phir bhi apply hongi.

### 3. Bigetar

| Result | Winning chance | Gross payout |
|---|---:|---:|
| BMW | 11.25% | 8x |
| Porsche | 5% | 18x |
| Land Rover | 1.3636% | 66x |
| Ferrari | 1.8% | 50x |
| Lamborghini | 0.9% | 100x |
| Bugatti | 1.0227% | 88x |
| Rolls-Royce | 3% | 30x |
| Mercedes | 4.5% | 20x |
| No Win | 71.1637% | 0x |

66x aur 88x ki probabilities integer weights ke liye neeche round ki gayi hain; inka RTP 90% se bahut halka kam hai. No Win mein kisi car ki bet payout nahi leti. Is high loss probability ko Rules aur bet-confirmation par chhupaya nahi jayega.

### 4. Slot Jackpots

| Result | Winning chance | Gross payout |
|---|---:|---:|
| No Win | 70% | 0x |
| Mini | 23% | 2x |
| Minor | 6% | 5x |
| Major | 0.9% | 10x |
| Grand | 0.1% | 50x |

5-reel/3-row display mein sirf center horizontal line active hogi. Mini: pehle 3 BAR, fourth alag; Minor: pehle 3 diamond, fourth alag; Major: pehle 4 seven, fifth alag; Grand: 5 seven. No Win grid in winning patterns se match nahi karega. Server outcome ke saath exact reel grid save karega. WILD substitution aur extra paylines is v1 mein shamil nahi.

MINI/MINOR/MAJOR/GRAND fixed multiplier tiers hain, progressive cash/coin pools nahi. Fake jackpot balances nahi dikhaye jayenge.

### 5. Teen Patti — A/B/C draw

| Result | Winning chance | Gross payout |
|---|---:|---:|
| Player A | 45% | 2x |
| Player B | 10% | 9x |
| Player C | 45% | 2x |

Card pictures reference illustrations hain; unse traditional poker hand ranking ya fair deck-dealing ka daawa nahi hoga. Agar traditional Teen Patti chahiye to deck, shuffling, hands, turns, stakes aur player-disconnect ke rules alag approve karne honge.

### 6. Lucky Wheel 77

| Result | Winning chance | Gross payout |
|---|---:|---:|
| No Win | 69.03% | 0x |
| 2x | 25% | 2x |
| 5x A | 5% | 5x |
| 10x | 0.5% | 10x |
| 20x | 0.2% | 20x |
| 50x | 0.05% | 50x |
| 100x | 0.01% | 100x |
| 150x | 0.01% | 150x |
| 5x B | 0.2% | 5x |

5x A aur 5x B do alag sectors hain. **No Win naya ninth result** hoga. Wheel par unequal odds saaf dikhani hongi; equal-size sectors ko equal chance keh kar nahi dikhayenge. 77 center branding hai; extra undocumented bonus nahi.

### 7. Bounty Football — virtual round

| Result | Winning chance | Gross payout |
|---|---:|---:|
| Home | 40% | 2.25x |
| Draw | 20% | 4.5x |
| Away | 40% | 2.25x |

Har virtual round mein Home/Draw/Away mein se ek result aayega. No Win ki zaroorat nahi; adjusted payouts ke saath har selection ka RTP 90% hai. Real match prediction, live score aur external sports feed is version mein shamil nahi.

## Auto Play, reconnect aur refunds

- Auto Play default off. Har activation par user maximum 20 rounds aur maximum 500,000 total coins ka budget confirm karega; room/game selection aur server bet limits phir bhi apply hongi.
- App background, room leave, disconnect, insufficient balance, budget/round cap, changed rules ya game disable hone par naye automatic wagers band. Dobara foreground/reconnect par fresh explicit activation chahiye. Already accepted wager normal settle hoga.
- Minimize/restore ya screen dobara kholne se bet/result duplicate nahi hoga; server round, bet aur settlement history restore hogi. Animation miss hone se winnings miss nahi hongi.
- Accepted request ka unique key same payload ke saath retry ho to wahi result wapas, dobara debit/credit nahi. Same key aur changed payload reject.
- Debit, bet row aur ledger entry ek transaction mein. Settlement/payout atomic aur exactly once. Insufficient balance par partial bet nahi.
- User ke disconnect ko loss, refund ya naya result banane ki wajah nahi banayenge. Outcome network reconnect par change nahi hoga.
- Server processing failure mein accepted unsettled round 60 seconds tak recover hoga. Phir server sweeper usi round lock ke andar settle karega, ya unresolvable technical cancellation par full stake exactly once refund karega. Scheduled sweeper har minute chalega.
- Normal No Win/game loss technical cancellation nahi, us par refund nahi. Admin game ko disable kare to existing accepted rounds defined settlement/refund path se close honge.
- Har round ka seed hash betting se pehle publish; secret seed private schema mein. Settlement ke baad seed aur versioned draw details verification ke liye reveal. Unsettled secret seed API/Realtime/client se read nahi ho sakta.
- History mein room, game, round, stake breakdown, gross payout, net change, outcome, UTC time, rules version aur request key/reference dikhayenge. Financial entries reset/delete nahi hongi.

## Daily Task rewards

| Task | Eligibility | Proposed reward | Claim limit |
|---|---|---:|---|
| Daily check-in | Active, email-verified account; server par aaj ka check-in | 1,000 coins | Har UTC din ek |
| Send a gift | Aaj successful non-self paid gift; total 1,000+ coins; settled gift event | 500 coins | Har UTC din ek |
| Stay in a room 10 min | Aaj 10 server-credited room minutes; same room zaroori nahi | 500 coins | Har UTC din ek |

- Account kam az kam 24 hours purana ho; sirf profile screen/local timer ya repeated client taps eligibility nahi banayenge.
- Har user ko ek earned UTC din ke liye maximum **2,000 Task coins**. UTC date server decide karega; phone timezone/date badalne se extra claim nahi.
- Gift eligibility authoritative settled gift event se hogi; failed, zero-cost aur self gifts qualify nahi. Gift price/split ke existing rules nahi badlenge.
- Room time existing verified activity heartbeat se aayega. Ek account ko overlapping rooms/devices se double minutes nahi. Cached/local fabricated time accept nahi.
- Proposed global Task credit budget **10,000,000 coins per UTC day**. Claim atomic budget check karega; budget khatam ho to coin credit aur claim marker dono nahi likhenge. Earned claim 7 days tak retry ho sakta hai; UI expiry aur pending-budget state dikhayegi.
- Unique `(user, task, earned_utc_date)` claim; parallel taps/retries se ek hi ledger credit. Claim response aur wallet/Task history immediately refresh hongi.
- Rewards alag ledger kind mein; fake recharge, paid-spend, Wealth, Charm ya gift history na banayen. 1 USD = 500,000 coins wale existing economy ratio par 2,000 coins ki reference value $0.004 hai; yeh cash withdrawal promise nahi.
- Koi hidden streak multiplier, VIP requirement, referral reward, ad reward ya client-side automatic credit is proposal mein shamil nahi.

## Backend aur app mein kya banana hoga

Existing Supabase, wallets, ledger, room-membership checks aur game history ko reuse karenge. Naye slugs ko legacy fruit_party/fruit_wheel ki identity ke naam par silently enable nahi karenge. Versioned approved config, room rounds, wager/settlement/refund idempotency, private seeds, result history aur Task progress/claim contracts minimum compatible migrations se add honge. Existing users, IDs, balances aur records preserve rahenge.

Flutter Rules sheet har game ki exact odds aur gross/net example dikhayegi. Bet button par actual total, group cost aur limit violations saaf honge. Room game overlay, timers, history, reconnect, Task progress/claims aur error/retry server state se chalenge. Client mein coin-authority ya random payout code nahi hoga.

## Enable karne se pehle zaroori checks

- Har game ke weights ka total 1,000,000; exact RTP maths; No Win aur grouped options; cap/boundary checks.
- Unauthenticated/non-member/banned/suspended caller, doosre user ka history/seed/claim read aur forged balance/result deny.
- Same aur changed-payload retries, parallel wagers/claims, low balance, deadline race, settlement/refund race aur worker restart.
- Reconnect/minimize/room leave/background ke baad pending bet aur Auto Play stop behavior.
- Task duplicate-day/device/timezone attempts, self-gift exclusion, fake room-time claims, global budget exhaustion aur pending-claim retry.
- Flutter analyze/tests; disposable database tests; production-compatible migration rehearsal; final APK install/open; device par authenticated flow verification jahan device available ho.

**Approval abhi pending hai.** Is sheet ko approve karna sirf upar defined game/reward rules ko approve karega; isse permanent Android signing key, Play Store/provider credentials, real device voice testing ya baqi undefined room-tool policies apne aap available nahi honge.
