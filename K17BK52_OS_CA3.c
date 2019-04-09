#include<stdio.h>
#include <pthread.h>
#include<unistd.h>
#include <windows.h>
struct THREAD_CREATION
{
    int var_pid;
    int process_bit;
}s[2700];

int MinPid=300;
int MaxPid=3000;
int n;
int VarOfThread=1;
pthread_mutex_t l;
int Allocate_Map();
int Allocate_Pid();
void Release_Pid(int pid);

void *Create_Thread(void* voida)                          //created thread call this function(Ex 4.20)
{
	    int i=VarOfThread;
        pthread_mutex_lock(&l);
    	Sleep(2000);
    	printf("\n\n\t\tTHREAD-%d with PID-%d",i,s[i].var_pid);
    	int k=s[i].var_pid;
    	VarOfThread++;
    	pthread_mutex_unlock(&l);
    	Sleep(5);
    	Release_Pid(k);                                        //pid gets released
}

int main()
{
	int k=0;
	printf("\nEnter Number of Threads you want to create :");
	scanf("%d",&n);
	pthread_t th[n];
	pthread_mutex_init(&l, NULL);
	struct THREAD_CREATION s[n];
	Allocate_Map();
    Allocate_Pid();
    printf("\n\n THREADS CREATED AS FOLLOWS ALONG WITH PID :");
	for(k = 0; k < n; k++)
    {
       pthread_create(&th[k],NULL, &Create_Thread,NULL);
        pthread_join(th[k], NULL);
    }

    for(k= 0; k< n; k++)
    {
        pthread_mutex_destroy(&l);
    }

	return 0;

}

int Allocate_Map()
{
    int i,j;
    for(j = MinPid, i =0; j <=MinPid+n; i++, j++)
    {
         s[i].var_pid= j;
        s[i].process_bit = 0;
    }
    if(i == MaxPid && j == 2700)
    {
    return 1;
	}
	if(n>MaxPid)
	{
		return -1;
		}
	else
    return -1;
}
int Allocate_Pid(void)
{
  for(int i = MinPid; j =0; i <= MinPid+n &&j<n; i++, j++)
    {
        if(s[i].process_bit == 0)
        {
            s[i].var_pid= i;
           s[i].process_bit = 1;
            return i;
            break;
        }
    }
    return -1;
}

void Release_Pid(int pid)
{
    for(int i = 0; i <= n; i++)
    {
        if(s[i].var_pid == pid)
        {
            s[i].process_bit = 0;
        }
    }
}
