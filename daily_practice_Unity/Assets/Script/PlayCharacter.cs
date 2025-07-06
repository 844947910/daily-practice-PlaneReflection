using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlayCharacter : MonoBehaviour
{
    // Start is called before the first frame update
    public float Speed = 5;

    // public float Strength = 1.0f;
    // public float interactiveDis = 1.5f;

    private bool isPlayPositionLogged = false;

    // Update is called once per frame
    void Update()
    {
        // Vector3 playPosition = this.transform.position;
        // //把变量传递进来
        // Shader.SetGlobalVector("_PlayPosition", playPosition);
        //
        // Shader.SetGlobalFloat("_interactiveDis", interactiveDis);
        //
        //
        // if (!isPlayPositionLogged)
        // {
        //     Debug.Log("Global _PlayPosition set to: " + playPosition);
        //
        //     Debug.Log("Global _Strength set to: " + interactiveDis);
        //     isPlayPositionLogged = true; 
        // }


        float horizontall = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");

        Vector3 movement = new Vector3(horizontall, 0.0f, vertical).normalized;
        MoveCharacter(movement);
    }

    void MoveCharacter(Vector3 direction)
    {
        if (direction.magnitude >= 0.2f)
            transform.Translate(direction * Speed * Time.deltaTime, Space.World);
    }
}