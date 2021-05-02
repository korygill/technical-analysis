/*
Build, Select Files
"SierraDev\kg_NewStudyTemplate.cpp"
*/
#include "sierrachart.h"
SCDLLName("kg_NewStudyTemplate")
const SCString ContactInformation = "Kory Gill, @korygill (twitter)";
#define ENABLE_SIERRA_USER_ACCESS_CHECKS 0
#define ENABLE_INTERNAL_USER_ACCESS_CHECKS 1
#define ENABLE_EXPIRATION_CHECKS 1
const char EXPIRATION_DATE[] = "2021-08-01";


#pragma region Useful but not essential to study calculation code
#if ENABLE_INTERNAL_USER_ACCESS_CHECKS
// ===========================================================================================
// Get User Authorization
// ===========================================================================================
int GetUserAuthorization(SCStudyInterfaceRef sc) 
{
    // AuthorizedUsers
    SCString AuthorizedUsers[] = {
        "AC125393" // kory
    };
    int AuthorizedUsersCount = sizeof(AuthorizedUsers)/sizeof(AuthorizedUsers[0]);
    int IsAuthorizedUser = 0;
    SCString msg;

    for (int user=0; user<AuthorizedUsersCount; user++) {
        if (sc.UserName().CompareNoCase(AuthorizedUsers[user]) == 0) {
            msg.Format("User %s is AUTHORIZED.", AuthorizedUsers[user].GetChars());
            sc.AddMessageToLog(msg, 0);
            IsAuthorizedUser = 1;
            break;
        }
    }

    if (IsAuthorizedUser == 0) {
        msg.Format("User %s is NOT AUTHORIZED!", sc.UserName().GetChars());
        sc.AddMessageToLog(msg, 0);
    }

    return IsAuthorizedUser;
}
#endif

// Friendly Names for Colors
const unsigned int RGB_Red = RGB(255, 0, 0);
const unsigned int RGB_Red210 = RGB(210, 0, 0);
const unsigned int RGB_Green = RGB(0, 255, 0);
const unsigned int RGB_Green210 = RGB(0, 210, 0);
const unsigned int RGB_Blue = RGB(0, 0, 255);
const unsigned int RGB_Magenta = RGB(255, 0, 255);
const unsigned int RGB_Yellow = RGB(255, 255, 0);
const unsigned int RGB_LightYellow = RGB(255, 255, 128);
const unsigned int RGB_Cyan = RGB(0, 255, 255);
const unsigned int RGB_Cyan210 = RGB(0, 210, 210);
const unsigned int RGB_White = RGB(255, 255, 255);
const unsigned int RGB_Black = RGB(0, 0, 0);
const unsigned int RGB_Pink = RGB(255, 128, 192);
const unsigned int RGB_Purple = RGB(128, 128, 192);
const unsigned int RGB_LimeGreen = RGB(128, 255, 0);
const unsigned int RGB_HotPink = RGB(255, 0, 128);


// ===========================================================================================
// Expiration and Time
// ===========================================================================================
SCDateTime GetNow(SCStudyInterfaceRef sc) 
{
    //https://www.sierrachart.com/index.php?page=doc/ACSIL_Members_Functions.html#scGetCurrentDateTime
    if (sc.IsReplayRunning()) {
        return sc.CurrentDateTimeForReplay; 
    } else {
        return sc.CurrentSystemDateTime;
    }
}


#pragma region Expiration
#if ENABLE_EXPIRATION_CHECKS
// ===========================================================================================
// IsExpired
// ===========================================================================================
bool IsExpired(SCStudyInterfaceRef sc) 
{
    SCString DateString (EXPIRATION_DATE);
    SCDateTime futureDate;
    futureDate = sc.DateStringToSCDateTime(DateString);

    return GetNow(sc) >= futureDate;
}


// ===========================================================================================
// CreateExpirationText
// Text Helper Function
// ===========================================================================================
void CreateExpirationText(SCStudyInterfaceRef sc)
{
    //
    // Text
    //
	s_UseTool Tool;
	Tool.Clear(); // reset tool structure for our next use
	Tool.ChartNumber = sc.ChartNumber;
	Tool.DrawingType = DRAWING_TEXT;
	Tool.Region	 = sc.GraphRegion;
	Tool.FontFace = sc.ChartTextFont(); 
	Tool.FontBold = true;
	Tool.ReverseTextColor = 0;
    Tool.Color = RGB_Red;
	Tool.FontSize = 10;
	Tool.LineNumber = 0xDEADBEEF;
    Tool.AddMethod = UTAM_ADD_OR_ADJUST;
    Tool.UseRelativeVerticalValues = 1;
    Tool.BeginValue = 50; // vertical % 0 - 100
    Tool.BeginDateTime = 50; // horizontal % 1-150
    Tool.DrawUnderneathMainGraph = 0; // 0 is above the main graph

    SCString msg = "";
    msg.Append("==============================\r\n");
    msg.Append("|  Study %s\r\n");
    msg.Append("|  expired on %s.\r\n");
    msg.Append("==============================\r\n");

    Tool.Text.Format(msg,
        sc.GetStudyNameUsingID(sc.StudyGraphInstanceID).GetChars(),
        EXPIRATION_DATE
        );

  	sc.UseTool(Tool);
}
#endif
#pragma endregion Useful but not essential to study calculation code


// ===========================================================================
// LogDateTime
// ===========================================================================
void LogDateTime(SCStudyInterfaceRef sc, SCDateTime& time) {
    SCString msg;
    msg.Format("now: %.4d-%.2d-%.2d %.2d:%.2d:%.2d",
        time.GetYear(), time.GetMonth(), time.GetDay(), 
        time.GetHour(), time.GetMinute(), time.GetSecond());
    sc.AddMessageToLog(msg, 1);
}
#pragma endregion Helper Code


// ===========================================================================
// scsf_NewStudyTemplate
// ===========================================================================
SCSFExport scsf_NewStudyTemplate(SCStudyInterfaceRef sc)
{
    int i;

#if ENABLE_INTERNAL_USER_ACCESS_CHECKS
    // Lock this study down to just authorized users
    int& r_IsAuthorizedUser = sc.GetPersistentIntFast(0);
#endif

    //
    // Subgraphs
    //
    i = 0;
    SCSubgraphRef Subgraph_MovingAverage = sc.Subgraph[i++];
    int NumSubgraphs = i;

    //
    // Inputs
    //
    i = 0;
    SCInputRef Input_Sensitivity = sc.Input[i++];
    SCInputRef Input_Length = sc.Input[i++];
    SCInputRef Input_Threshold = sc.Input[i++];

    //
    // Set Defaults
    // 
    if (sc.SetDefaults)
    {
        SCString msg;
        msg.Format("sc.SetDefaults");
        //sc.AddMessageToLog(msg, 0);

        // Initialize Defaults
        sc.GraphName = "New Study Template";
        SCString studyDescription;
        studyDescription.Format("%s by %s", sc.GraphName.GetChars(), ContactInformation.GetChars());
        sc.StudyDescription = studyDescription;
        sc.AutoLoop = 1;
		sc.DrawZeros = 0;
        sc.GraphRegion = 0;
        sc.DrawStudyUnderneathMainPriceGraph = 0;

#pragma region Subgraphs
        Subgraph_MovingAverage.Name = "Moving Average";
        Subgraph_MovingAverage.DrawStyle = DRAWSTYLE_LINE;
        Subgraph_MovingAverage.LineWidth = 2;
        Subgraph_MovingAverage.PrimaryColor = RGB_Magenta;
        Subgraph_MovingAverage.SecondaryColor = RGB_Yellow;
        Subgraph_MovingAverage.SecondaryColorUsed = 1;
#pragma endregion Subgraphs
        
#pragma region Inputs
        Input_Length.Name = "Length";
        Input_Length.SetDescription("The moving average length.");
        Input_Length.SetInt(21);
#pragma endregion Inputs

#if ENABLE_INTERNAL_USER_ACCESS_CHECKS
        //
        // Security Check
        //
        r_IsAuthorizedUser = GetUserAuthorization(sc);
#endif

        return;
    }


#pragma region Useful but not essential to study calculation code
#pragma region ACCESS CHECKS
    //
    // Expiration Checks
    //
#if ENABLE_EXPIRATION_CHECKS
    if (IsExpired(sc)) 
    {
        CreateExpirationText(sc);
        return;
    }
#endif

    //
    // User Access Checks for when distributed via direct dll sharing.
    //
#if ENABLE_INTERNAL_USER_ACCESS_CHECKS
    if (r_IsAuthorizedUser == 0)
    {
        if (sc.Index == 0)
        {
            SCString msg;
            msg.Format("You are not authorized to use this study. Contact %s to discuss authorization.", ContactInformation.GetChars());
            sc.AddMessageToLog(msg, 1);
        }
        return;
    }
#endif

    //
    // User Access Checks for when distributed via Sierra.
    //
#if ENABLE_SIERRA_USER_ACCESS_CHECKS
    if (sc.IsUserAllowedForSCDLLName == false)
    {
        if (sc.Index == 0)
        {
            SCString msg;
            msg.Format("You are not authorized to use this study. Contact %s to discuss authorization.", ContactInformation.GetChars());
            sc.AddMessageToLog(msg, 1);
        }
        return;
    }
#endif
#pragma endregion ACCESS CHECKS
#pragma endregion Useful but not essential to study calculation code


    //
    // MAIN STUDY CODE
    //

    // Init variables
  	SCDateTime CurrentBarDateTime = sc.BaseDateTimeIn[sc.Index];

    //
    // Full recalculation
    // 
    if (sc.IsFullRecalculation && sc.Index == 0) {
    }


    //
    // Study Logic
    //
    sc.ExponentialMovAvg(sc.Close, Subgraph_MovingAverage, Input_Length.GetInt());

    // Colorization
    if (Subgraph_MovingAverage[sc.Index] >= sc.Close[sc.Index]) {
        Subgraph_MovingAverage.DataColor[sc.Index] = Subgraph_MovingAverage.PrimaryColor;
    } else {
        Subgraph_MovingAverage.DataColor[sc.Index] = Subgraph_MovingAverage.SecondaryColor;
    }
}
