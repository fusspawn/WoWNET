using System;
using System.Collections.Generic;
using System.Text;
using Wrapper.API;

namespace Wrapper.UI
{
    public class NativeErrorLoggerUI
    {
        public List<ErrorMessageData> ErrorMessages;
        public StdUI.StdUiFrame MainFrame;
        public class ErrorMessageData
        {
            public double RecordedAt;
            public string Message;
            public string Stack;
        }


        private static NativeErrorLoggerUI instance;
        public static NativeErrorLoggerUI Instance
        {
            get { return instance; }
        }

        public void AddErrorMessage(string Message, string Stack)
        {
            ErrorMessages.Add(new ErrorMessageData() { Message = Message, Stack = Stack, RecordedAt = WoWAPI.GetTime() });
        }
    }
}
