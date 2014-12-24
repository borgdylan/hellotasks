//Copyright 2014 Dylan Borg
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//http://www.apache.org/licenses/LICENSE-2.0
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

#include "msbuild.dyl"

import System
import System.IO
import System.Threading
import System.Threading.Tasks

class private ReaderClosure extends DisposerTaskClosure<of StreamReader>

	field private StreamReader _sr
	field private long _n
	
	method public void ReaderClosure(var sr as StreamReader)
		mybase::ctor(sr)
		_sr = sr
		_n = 0l
	end method
	
	method public void LineAwaiter(var line as string)
		if line == null then
			Console::WriteLine()
			Console::WriteLine("Read {0} lines!", $object$_n)
			Return()
		else
			Console::WriteLine(line)
			_n++
			Await<of string>(_sr::ReadLineAsync(), new Action<of string>(LineAwaiter))
		end if
	end method

end class

class private LoopClosure extends TaskClosure

	field private integer _i
	
	method public void LoopClosure()
		mybase::ctor()
		_i = 1
	end method
	
	method public void DelayLoop()
		Console::WriteLine("d {0} {1}", DateTime::get_Now()::ToString(), $object$Thread::get_CurrentThread()::get_ManagedThreadId())
		if _i < 10 then
			_i++
			Await(Task::Delay(1000), new Action(DelayLoop))
		else
			Return()
		end if
	end method
	
	method public void LongLoop()
		Console::WriteLine("d {0} {1}", DateTime::get_Now()::ToString(), $object$Thread::get_CurrentThread()::get_ManagedThreadId())
		if _i < 120 then
			_i++
			Await(Task::Delay(1000), new Action(LongLoop))
		else
			Return()
		end if
	end method
	
	method public void YieldLoop()
		Console::WriteLine("y {0} {1}", DateTime::get_Now()::ToString(), $object$Thread::get_CurrentThread()::get_ManagedThreadId())
		if _i < 10 then
			_i++
			Await(Task::Yield(), new Action(YieldLoop))
		else
			Return()
		end if
	end method
	
end class

class private ExceptionClosure extends TaskClosure
	
	method public void ExceptionClosure()
		mybase::ctor()
	end method
	
	method public override void Catch(var e as Exception)
		throw e
	end method
	
	method public override void Catch2(var e as Exception)
		throw new Exception("Caught an exeption", e)
	end method
	
	method public void Throw()
		throw new Exception("Test exception, thrown on purpose.")
	end method
	
end class

class private LogClosure extends TaskClosure
	
	method public void LogClosure()
		mybase::ctor()
	end method
	
	method public void Log()
		Return()
	end method
	
	method public void Log(var ex as Exception)
		if ex is TaskCanceledException then
			Console::WriteLine("The underlying task got canceled!")
		else
			Console::WriteLine(ex::ToString())
		end if
		
		Return()
	end method
	
end class

class public Program
	
	method public Task ReadAsync()
		Console::WriteLine("Starting to read file.txt...")
		Console::WriteLine()
		
		//echoes standard input
		//var sr = new StreamReader(Console::OpenStandardInput())
		
		//echoes contents of file.txt
		var sr = new StreamReader(File::OpenRead("file.txt"))
		
		var clos = new ReaderClosure(sr)
		return clos::Await<of string>(sr::ReadLineAsync(), new Action<of string>(clos::LineAwaiter))
	end method
	
	method public Task DelayLoopAsync()
		var clos = new LoopClosure()
		return clos::Await(Task::Delay(1000), new Action(clos::DelayLoop))
	end method
	
	method public Task LongLoopAsync(var ck as CancellationToken)
		var clos = new LoopClosure() {set_Canceller(ck)}
		return clos::Await(Task::Delay(1000), new Action(clos::LongLoop))
	end method
	
	method public Task YieldLoopAsync()
		var clos = new LoopClosure()
		return clos::Await(Task::Yield(), new Action(clos::YieldLoop))
	end method
	
	method public Task ThrowAsync()
		var clos = new ExceptionClosure()
		return clos::Await<of Exception>(Task::Yield(), new Action(clos::Throw), new Action<of Exception>(clos::Catch2))
	end method
	
	method public Task LogAsync(var t as Task)
		var clos = new LogClosure()
		return clos::Await<of Exception>(t, new Action(clos::Log), new Action<of Exception>(clos::Log))
	end method
	
	method public Task Main()
		var cks = new CancellationTokenSource()
		var t = LogAsync(LongLoopAsync(cks::get_Token()))
		Console::ReadLine()
		cks::Cancel()
		return t
	end method

end class
